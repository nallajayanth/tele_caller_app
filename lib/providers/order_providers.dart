import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/order_model.dart';
import 'auth_providers.dart';

class OrderNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  RealtimeChannel? _subscription;
  String? lastUploadError;

  OrderNotifier() : super(const AsyncLoading()) {
    loadOrders();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    try {
      _subscription = Supabase.instance.client
          .channel('public:orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (PostgresChangePayload payload) {
              _handleRealtimeChange(payload);
            },
          );
      _subscription?.subscribe();
    } catch (_) {}
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    state.whenData((currentOrders) {
      final list = List<OrderModel>.from(currentOrders);
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      if (payload.eventType == PostgresChangeEvent.insert) {
        if (newRecord.isNotEmpty) {
          final order = OrderModel.fromJson(newRecord);
          if (!list.any((o) => o.id == order.id)) {
            list.insert(0, order);
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            state = AsyncData(list);
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        if (newRecord.isNotEmpty) {
          final order = OrderModel.fromJson(newRecord);
          final idx = list.indexWhere((o) => o.id == order.id);
          if (idx != -1) {
            list[idx] = order;
          } else {
            list.add(order);
          }
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = AsyncData(list);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        if (oldRecord.isNotEmpty) {
          final id = oldRecord['id'] as String?;
          if (id != null) {
            list.removeWhere((o) => o.id == id);
            state = AsyncData(list);
          }
        }
      }
    });
  }

  Future<void> loadOrders() async {
    state = const AsyncLoading();
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      final orders = (response as List<dynamic>)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncData(orders);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<String?> uploadPhoto(String bucket, String filePath, String fileName) async {
    lastUploadError = null;
    try {
      final file = File(filePath);
      final client = Supabase.instance.client;
      final path = fileName;
      
      await client.storage.from(bucket).upload(path, file, fileOptions: const FileOptions(upsert: true));
      final String publicUrl = client.storage.from(bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Upload failed: $e');
      lastUploadError = e.toString();
      return null;
    }
  }

  Future<bool> updateOrderStatus(
    String orderId,
    String callLogId,
    String status, {
    String? packedPhotoUrl,
    String? dispatchedPhotoUrl,
    String? logisticsProvider,
    String? trackingId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final nowStr = DateTime.now().toIso8601String();

      final Map<String, dynamic> updateData = {
        'status': status,
        'updated_at': nowStr,
      };
      if (packedPhotoUrl != null) updateData['packed_photo_url'] = packedPhotoUrl;
      if (dispatchedPhotoUrl != null) updateData['dispatched_photo_url'] = dispatchedPhotoUrl;
      if (logisticsProvider != null) updateData['logistics_provider'] = logisticsProvider;
      if (trackingId != null) updateData['tracking_id'] = trackingId;


      await client.from('orders').update(updateData).eq('id', orderId);

      // 2. Update call_logs table to sync status
      await client.from('call_logs').update({
        'order_status': status,
        'order_status_updated_at': nowStr,
      }).eq('id', callLogId);

      // Reload orders
      await loadOrders();
      return true;
    } catch (e) {
      debugPrint('Update order status failed: $e');
      return false;
    }
  }

  Future<String?> ensureOrderAndMarkPacked({
    required String callLogId,
    required String customerName,
    required String product,
    required double orderValue,
    required String deviceId,
    required List<String> imageFilePaths,
  }) async {
    try {
      final client = Supabase.instance.client;
      final List<String> urls = [];

      for (int i = 0; i < imageFilePaths.length; i++) {
        final filePath = imageFilePaths[i];
        final file = File(filePath);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'packed_${callLogId}_${timestamp}_$i.jpg';

        // Upload directly so we catch the exact error (e.g. StorageException, AuthException, etc.)
        await client.storage.from('status_tracking').upload(
          fileName,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

        final String url = client.storage.from('status_tracking').getPublicUrl(fileName);
        urls.add(url);
      }

      final String combinedUrlString = urls.join(',');
      final nowStr = DateTime.now().toIso8601String();

      final existing = await client
          .from('orders')
          .select('id')
          .eq('id', callLogId)
          .maybeSingle();

      if (existing == null) {
        await client.from('orders').insert({
          'id': callLogId,
          'call_log_id': callLogId,
          'customer_name': customerName,
          'product': product,
          'order_value': orderValue,
          'status': 'packed',
          'packed_photo_url': combinedUrlString,
          'assigned_staff_device_id': deviceId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });
      } else {
        await client.from('orders').update({
          'status': 'packed',
          'packed_photo_url': combinedUrlString,
          'updated_at': nowStr,
        }).eq('id', callLogId);
      }

      await client.from('call_logs').update({
        'order_status': 'packed',
        'order_status_updated_at': nowStr,
      }).eq('id', callLogId);

      await loadOrders();
      return null;
    } catch (e) {
      debugPrint('ensureOrderAndMarkPacked failed: $e');
      return e.toString();
    }
  }

  @override
  void dispose() {
    if (_subscription != null) {
      Supabase.instance.client.removeChannel(_subscription!);
    }
    super.dispose();
  }
}

final ordersProvider = StateNotifierProvider<OrderNotifier, AsyncValue<List<OrderModel>>>((ref) {
  return OrderNotifier();
});

// Helper provider to filter orders by status
final ordersByStatusProvider = Provider.family<List<OrderModel>, String>((ref, status) {
  final ordersAsync = ref.watch(ordersProvider);
  return ordersAsync.when(
    data: (orders) => orders.where((o) => o.status.toLowerCase() == status.toLowerCase()).toList(),
    loading: () => [],
    error: (_, st) => [],
  );
});

class DailyOrderStats {
  final int newOrdersToday;
  final int pendingDispatch;
  final int packedToday;
  final int dispatchedToday;
  final int exceeded24h;

  const DailyOrderStats({
    required this.newOrdersToday,
    required this.pendingDispatch,
    required this.packedToday,
    required this.dispatchedToday,
    required this.exceeded24h,
  });
}

final globalOrderStatsProvider = Provider<DailyOrderStats>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  return ordersAsync.maybeWhen(
    data: (orders) {
      final now = DateTime.now();
      int newOrders = 0;
      int pending = 0;
      int packed = 0;
      int dispatched = 0;
      int exceeded = 0;

      for (final o in orders) {
        final isCreatedToday = o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day;
        final isUpdatedToday = o.updatedAt.year == now.year && o.updatedAt.month == now.month && o.updatedAt.day == now.day;
        final status = o.status.toLowerCase();

        if (status == 'received' && isCreatedToday) {
          newOrders++;
        }
        if (status == 'packed') {
          pending++; // Packed and waiting
        }
        if ((status == 'packed' || status == 'dispatched') && isUpdatedToday) {
          packed++; // Packed today
        }
        if (status == 'dispatched' && isUpdatedToday) {
          dispatched++; // Dispatched today
        }
        if (status == 'received' && now.difference(o.createdAt).inHours >= 24) {
          exceeded++; // Exceeded 24h & unpacked
        }
      }

      return DailyOrderStats(
        newOrdersToday: newOrders,
        pendingDispatch: pending,
        packedToday: packed,
        dispatchedToday: dispatched,
        exceeded24h: exceeded,
      );
    },
    orElse: () => const DailyOrderStats(
      newOrdersToday: 0,
      pendingDispatch: 0,
      packedToday: 0,
      dispatchedToday: 0,
      exceeded24h: 0,
    ),
  );
});

final staffOrderStatsProvider = Provider<DailyOrderStats>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return ordersAsync.maybeWhen(
    data: (orders) {
      final now = DateTime.now();
      int newOrders = 0;
      int pending = 0;
      int packed = 0;
      int dispatched = 0;
      int exceeded = 0;

      final myOrders = orders.where((o) => o.assignedStaffDeviceId == deviceId);

      for (final o in myOrders) {
        final isCreatedToday = o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day;
        final isUpdatedToday = o.updatedAt.year == now.year && o.updatedAt.month == now.month && o.updatedAt.day == now.day;
        final status = o.status.toLowerCase();

        if (status == 'received' && isCreatedToday) {
          newOrders++;
        }
        if (status == 'packed') {
          pending++;
        }
        if ((status == 'packed' || status == 'dispatched') && isUpdatedToday) {
          packed++;
        }
        if (status == 'dispatched' && isUpdatedToday) {
          dispatched++;
        }
        if (status == 'received' && now.difference(o.createdAt).inHours >= 24) {
          exceeded++;
        }
      }

      return DailyOrderStats(
        newOrdersToday: newOrders,
        pendingDispatch: pending,
        packedToday: packed,
        dispatchedToday: dispatched,
        exceeded24h: exceeded,
      );
    },
    orElse: () => const DailyOrderStats(
      newOrdersToday: 0,
      pendingDispatch: 0,
      packedToday: 0,
      dispatchedToday: 0,
      exceeded24h: 0,
    ),
  );
});
