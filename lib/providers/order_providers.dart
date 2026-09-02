import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../data/models/order_model.dart';
import '../data/models/telecaller_model.dart';
import '../core/services/fcm_service.dart';
import 'auth_providers.dart';

class OrderNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  final Ref _ref;
  StreamSubscription? _subscription;
  String? lastUploadError;

  OrderNotifier(this._ref) : super(const AsyncLoading()) {
    loadOrders();
    _subscribeRealtime();
    _ref.listen<TelecallerModel?>(activeUserProvider, (previous, next) {
      if (previous?.role != next?.role || previous?.phoneNumber != next?.phoneNumber) {
        _subscribeRealtime();
        loadOrders();
      }
    });
  }

  void _subscribeRealtime() {
    try {
      _subscription?.cancel();
      final activeUser = _ref.read(activeUserProvider);
      final role = activeUser?.role;
      final deviceId = _ref.read(deviceIdProvider);

      Query query = FirebaseFirestore.instance.collection('orders');
      if (role != 'admin' && role != 'warehouse') {
        query = query.where('assigned_staff_device_id', isEqualTo: deviceId);
      }

      _subscription = query.snapshots().listen((snapshot) {
        try {
          final orders = snapshot.docs
              .map((doc) => OrderModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = AsyncData(orders);
        } catch (_) {
          loadOrders();
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> loadOrders() async {
    state = const AsyncLoading();
    try {
      final activeUser = _ref.read(activeUserProvider);
      final role = activeUser?.role;
      final deviceId = _ref.read(deviceIdProvider);

      Query query = FirebaseFirestore.instance.collection('orders');
      if (role != 'admin' && role != 'warehouse') {
        query = query.where('assigned_staff_device_id', isEqualTo: deviceId);
      }

      final snapshot = await query.get();

      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncData(orders);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<String?> uploadPhoto(String bucket, String filePath, String fileName) async {
    lastUploadError = null;
    try {
      final file = File(filePath);
      final ref = FirebaseStorage.instance.ref().child('$bucket/$fileName');
      await ref.putFile(file);
      final String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
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
      final client = FirebaseFirestore.instance;
      final nowStr = DateTime.now().toIso8601String();

      final Map<String, dynamic> updateData = {
        'status': status,
        'updated_at': nowStr,
      };
      if (packedPhotoUrl != null) updateData['packed_photo_url'] = packedPhotoUrl;
      if (dispatchedPhotoUrl != null) updateData['dispatched_photo_url'] = dispatchedPhotoUrl;
      if (logisticsProvider != null) updateData['logistics_provider'] = logisticsProvider;
      if (trackingId != null) updateData['tracking_id'] = trackingId;


      await client.collection('orders').doc(orderId).update(updateData);

      // 2. Update call_logs table to sync status
      await client.collection('call_logs').doc(callLogId).update({
        'order_status': status,
        'order_status_updated_at': nowStr,
      });

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
      final client = FirebaseFirestore.instance;
      final List<String> urls = [];

      for (int i = 0; i < imageFilePaths.length; i++) {
        final filePath = imageFilePaths[i];
        final file = File(filePath);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'packed_${callLogId}_${timestamp}_$i.jpg';

        final ref = FirebaseStorage.instance.ref().child('status_tracking/$fileName');
        await ref.putFile(file);
        final String url = await ref.getDownloadURL();
        urls.add(url);
      }

      final String combinedUrlString = urls.join(',');
      final nowStr = DateTime.now().toIso8601String();

      final docRef = client.collection('orders').doc(callLogId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
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

        // Notify Admins about the new order
        FCMService.instance.notifyAdminsOfNewOrder(
          deviceId: deviceId,
          customerName: customerName,
          product: product,
          orderValue: orderValue,
        );
      } else {
        await docRef.update({
          'status': 'packed',
          'packed_photo_url': combinedUrlString,
          'updated_at': nowStr,
        });
      }

      await client.collection('call_logs').doc(callLogId).update({
        'order_status': 'packed',
        'order_status_updated_at': nowStr,
      });

      await loadOrders();
      return null;
    } catch (e) {
      debugPrint('ensureOrderAndMarkPacked failed: $e');
      return e.toString();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final ordersProvider = StateNotifierProvider<OrderNotifier, AsyncValue<List<OrderModel>>>((ref) {
  return OrderNotifier(ref);
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

class OrderPipelineStats {
  final int newOrdersCount;
  final int pendingDispatch;
  final int packedCount;
  final int dispatchedCount;
  final int exceeded24h;

  const OrderPipelineStats({
    required this.newOrdersCount,
    required this.pendingDispatch,
    required this.packedCount,
    required this.dispatchedCount,
    required this.exceeded24h,
  });
}

final globalOrderStatsProvider = Provider<OrderPipelineStats>((ref) {
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

      return OrderPipelineStats(
        newOrdersCount: newOrders,
        pendingDispatch: pending,
        packedCount: packed,
        dispatchedCount: dispatched,
        exceeded24h: exceeded,
      );
    },
    orElse: () => const OrderPipelineStats(
      newOrdersCount: 0,
      pendingDispatch: 0,
      packedCount: 0,
      dispatchedCount: 0,
      exceeded24h: 0,
    ),
  );
});

final staffOrderStatsProvider = Provider<OrderPipelineStats>((ref) {
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

      return OrderPipelineStats(
        newOrdersCount: newOrders,
        pendingDispatch: pending,
        packedCount: packed,
        dispatchedCount: dispatched,
        exceeded24h: exceeded,
      );
    },
    orElse: () => const OrderPipelineStats(
      newOrdersCount: 0,
      pendingDispatch: 0,
      packedCount: 0,
      dispatchedCount: 0,
      exceeded24h: 0,
    ),
  );
});

final staffMonthlyOrderStatsProvider = Provider<OrderPipelineStats>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return ordersAsync.maybeWhen(
    data: (orders) {
      final now = DateTime.now();
      int newOrders = 0;
      int pending = 0;
      int packed = 0;
      int dispatched = 0;

      final myOrders = orders.where((o) => o.assignedStaffDeviceId == deviceId);

      for (final o in myOrders) {
        final isCreatedThisMonth = o.createdAt.year == now.year && o.createdAt.month == now.month;
        final isUpdatedThisMonth = o.updatedAt.year == now.year && o.updatedAt.month == now.month;
        final status = o.status.toLowerCase();

        if (status == 'received' && isCreatedThisMonth) {
          newOrders++;
        }
        if (status == 'packed') {
          pending++;
        }
        if ((status == 'packed' || status == 'dispatched') && isUpdatedThisMonth) {
          packed++;
        }
        if (status == 'dispatched' && isUpdatedThisMonth) {
          dispatched++;
        }
      }

      return OrderPipelineStats(
        newOrdersCount: newOrders,
        pendingDispatch: pending,
        packedCount: packed,
        dispatchedCount: dispatched,
        exceeded24h: 0,
      );
    },
    orElse: () => const OrderPipelineStats(
      newOrdersCount: 0,
      pendingDispatch: 0,
      packedCount: 0,
      dispatchedCount: 0,
      exceeded24h: 0,
    ),
  );
});
