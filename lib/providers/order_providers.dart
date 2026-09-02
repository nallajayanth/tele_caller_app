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
import 'call_log_providers.dart';

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
  final logsAsync = ref.watch(callLogsProvider);
  final now = DateTime.now();

  int newOrders = 0;
  int pending = 0;
  int packed = 0;
  int dispatched = 0;
  int exceeded = 0;

  final orders = ordersAsync.value ?? [];
  final logs = (logsAsync.value ?? []).where((l) => l.connectedStatus != '__system_config__').toList();

  final Set<String> todayOrderLogIds = {};

  for (final l in logs) {
    final logDateLocal = l.date.toLocal();
    final isCreatedToday = logDateLocal.year == now.year &&
        logDateLocal.month == now.month &&
        logDateLocal.day == now.day;

    final isOrderLog = l.connectedStatus.toLowerCase() == 'order received' ||
        (l.orderStatus ?? '').toLowerCase() == 'received' ||
        (l.orderValue > 0 && l.connectedStatus.toLowerCase() == 'connected');

    if (isCreatedToday && isOrderLog) {
      todayOrderLogIds.add(l.id);
    }
  }

  for (final o in orders) {
    final createdAtLocal = o.createdAt.toLocal();
    final isCreatedToday = createdAtLocal.year == now.year &&
        createdAtLocal.month == now.month &&
        createdAtLocal.day == now.day;

    if (isCreatedToday) {
      if (o.callLogId.isNotEmpty) todayOrderLogIds.add(o.callLogId);
      todayOrderLogIds.add(o.id);
    }
  }

  newOrders = todayOrderLogIds.length;

  for (final o in orders) {
    final createdAtLocal = o.createdAt.toLocal();
    final updatedAtLocal = o.updatedAt.toLocal();

    final isUpdatedToday = updatedAtLocal.year == now.year &&
        updatedAtLocal.month == now.month &&
        updatedAtLocal.day == now.day;

    final status = o.status.toLowerCase().trim();
    final isPacked = status == 'packed';
    final isDispatched = status == 'dispatched';
    final isReceived = status == 'received' ||
        status == 'order received' ||
        status == 'order_received' ||
        status == 'new';

    if (isPacked) {
      pending++;
    }
    if ((isPacked || isDispatched) && isUpdatedToday) {
      packed++;
    }
    if (isDispatched && isUpdatedToday) {
      dispatched++;
    }
    if (isReceived && now.difference(createdAtLocal).inHours >= 24) {
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
});

final staffOrderStatsProvider = Provider<OrderPipelineStats>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  final logsAsync = ref.watch(staffLogsProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final now = DateTime.now();

  int newOrders = 0;
  int pending = 0;
  int packed = 0;
  int dispatched = 0;
  int exceeded = 0;

  final orders = ordersAsync.value ?? [];
  final myOrders = orders.where((o) => o.assignedStaffDeviceId == deviceId);
  final logs = (logsAsync.value ?? []).where((l) => l.connectedStatus != '__system_config__').toList();

  final Set<String> todayOrderLogIds = {};

  for (final l in logs) {
    final logDateLocal = l.date.toLocal();
    final isCreatedToday = logDateLocal.year == now.year &&
        logDateLocal.month == now.month &&
        logDateLocal.day == now.day;

    final isOrderLog = l.connectedStatus.toLowerCase() == 'order received' ||
        (l.orderStatus ?? '').toLowerCase() == 'received' ||
        (l.orderValue > 0 && l.connectedStatus.toLowerCase() == 'connected');

    if (isCreatedToday && isOrderLog) {
      todayOrderLogIds.add(l.id);
    }
  }

  for (final o in myOrders) {
    final createdAtLocal = o.createdAt.toLocal();
    final isCreatedToday = createdAtLocal.year == now.year &&
        createdAtLocal.month == now.month &&
        createdAtLocal.day == now.day;

    if (isCreatedToday) {
      if (o.callLogId.isNotEmpty) todayOrderLogIds.add(o.callLogId);
      todayOrderLogIds.add(o.id);
    }

    final updatedAtLocal = o.updatedAt.toLocal();
    final isUpdatedToday = updatedAtLocal.year == now.year &&
        updatedAtLocal.month == now.month &&
        updatedAtLocal.day == now.day;

    final status = o.status.toLowerCase().trim();
    final isPacked = status == 'packed';
    final isDispatched = status == 'dispatched';
    final isReceived = status == 'received' ||
        status == 'order received' ||
        status == 'order_received' ||
        status == 'new';

    if (isPacked) {
      pending++;
    }
    if ((isPacked || isDispatched) && isUpdatedToday) {
      packed++;
    }
    if (isDispatched && isUpdatedToday) {
      dispatched++;
    }
    if (isReceived && now.difference(createdAtLocal).inHours >= 24) {
      exceeded++;
    }
  }

  newOrders = todayOrderLogIds.length;

  return OrderPipelineStats(
    newOrdersCount: newOrders,
    pendingDispatch: pending,
    packedCount: packed,
    dispatchedCount: dispatched,
    exceeded24h: exceeded,
  );
});

final staffMonthlyOrderStatsFamily = Provider.family<OrderPipelineStats, DateTime>((ref, targetDate) {
  final ordersAsync = ref.watch(ordersProvider);
  final logsAsync = ref.watch(staffLogsProvider);
  final deviceId = ref.watch(deviceIdProvider);

  int newOrders = 0;
  int pending = 0;
  int packed = 0;
  int dispatched = 0;

  final orders = ordersAsync.value ?? [];
  final myOrders = orders.where((o) => o.assignedStaffDeviceId == deviceId);
  final logs = (logsAsync.value ?? []).where((l) => l.connectedStatus != '__system_config__').toList();

  final Set<String> monthOrderLogIds = {};

  for (final l in logs) {
    final logDateLocal = l.date.toLocal();
    final isCreatedInMonth = logDateLocal.year == targetDate.year && logDateLocal.month == targetDate.month;

    final isOrderLog = l.connectedStatus.toLowerCase() == 'order received' ||
        (l.orderStatus ?? '').toLowerCase() == 'received' ||
        (l.orderValue > 0 && l.connectedStatus.toLowerCase() == 'connected');

    if (isCreatedInMonth && isOrderLog) {
      monthOrderLogIds.add(l.id);
    }
  }

  for (final o in myOrders) {
    final createdAtLocal = o.createdAt.toLocal();
    final isCreatedInMonth = createdAtLocal.year == targetDate.year && createdAtLocal.month == targetDate.month;

    if (isCreatedInMonth) {
      if (o.callLogId.isNotEmpty) monthOrderLogIds.add(o.callLogId);
      monthOrderLogIds.add(o.id);
    }

    final updatedAtLocal = o.updatedAt.toLocal();
    final isUpdatedInMonth = updatedAtLocal.year == targetDate.year && updatedAtLocal.month == targetDate.month;

    final status = o.status.toLowerCase().trim();
    final isPacked = status == 'packed';
    final isDispatched = status == 'dispatched';

    if (isPacked) {
      pending++;
    }
    if ((isPacked || isDispatched) && isUpdatedInMonth) {
      packed++;
    }
    if (isDispatched && isUpdatedInMonth) {
      dispatched++;
    }
  }

  newOrders = monthOrderLogIds.length;

  return OrderPipelineStats(
    newOrdersCount: newOrders,
    pendingDispatch: pending,
    packedCount: packed,
    dispatchedCount: dispatched,
    exceeded24h: 0,
  );
});

final staffMonthlyOrderStatsProvider = Provider<OrderPipelineStats>((ref) {
  return ref.watch(staffMonthlyOrderStatsFamily(DateTime.now()));
});

final staffDailyOrderStatsFamily = Provider.family<OrderPipelineStats, DateTime>((ref, targetDate) {
  final ordersAsync = ref.watch(ordersProvider);
  final logsAsync = ref.watch(staffLogsProvider);
  final deviceId = ref.watch(deviceIdProvider);

  int newOrders = 0;
  int pending = 0;
  int packed = 0;
  int dispatched = 0;

  final orders = ordersAsync.value ?? [];
  final myOrders = orders.where((o) => o.assignedStaffDeviceId == deviceId);
  final logs = (logsAsync.value ?? []).where((l) => l.connectedStatus != '__system_config__').toList();

  final Set<String> dayOrderLogIds = {};

  for (final l in logs) {
    final logDateLocal = l.date.toLocal();
    final isCreatedOnDay = logDateLocal.year == targetDate.year &&
        logDateLocal.month == targetDate.month &&
        logDateLocal.day == targetDate.day;

    final isOrderLog = l.connectedStatus.toLowerCase() == 'order received' ||
        (l.orderStatus ?? '').toLowerCase() == 'received' ||
        (l.orderValue > 0 && l.connectedStatus.toLowerCase() == 'connected');

    if (isCreatedOnDay && isOrderLog) {
      dayOrderLogIds.add(l.id);
    }
  }

  for (final o in myOrders) {
    final createdAtLocal = o.createdAt.toLocal();
    final isCreatedOnDay = createdAtLocal.year == targetDate.year &&
        createdAtLocal.month == targetDate.month &&
        createdAtLocal.day == targetDate.day;

    if (isCreatedOnDay) {
      if (o.callLogId.isNotEmpty) dayOrderLogIds.add(o.callLogId);
      dayOrderLogIds.add(o.id);
    }

    final updatedAtLocal = o.updatedAt.toLocal();
    final isUpdatedOnDay = updatedAtLocal.year == targetDate.year &&
        updatedAtLocal.month == targetDate.month &&
        updatedAtLocal.day == targetDate.day;

    final status = o.status.toLowerCase().trim();
    final isPacked = status == 'packed';
    final isDispatched = status == 'dispatched';

    if (isPacked) {
      pending++;
    }
    if ((isPacked || isDispatched) && isUpdatedOnDay) {
      packed++;
    }
    if (isDispatched && isUpdatedOnDay) {
      dispatched++;
    }
  }

  newOrders = dayOrderLogIds.length;

  return OrderPipelineStats(
    newOrdersCount: newOrders,
    pendingDispatch: pending,
    packedCount: packed,
    dispatchedCount: dispatched,
    exceeded24h: 0,
  );
});
