import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/datasources/firestore_datasource.dart';
import '../data/models/call_log_model.dart';
import '../data/models/order_model.dart';
import '../data/models/telecaller_model.dart';
import '../data/repositories/call_log_repository_impl.dart';
import '../domain/repositories/call_log_repository.dart';
import '../core/services/fcm_service.dart';
import '../core/services/stock_service.dart';
import 'auth_providers.dart';
import 'order_providers.dart';
import 'product_providers.dart';

const _uuid = Uuid();

// Device ID - generated once and stored in settings box
String get deviceId {
  final box = Hive.box('settings');
  String? id = box.get('device_id');
  if (id == null) {
    id = _uuid.v4();
    box.put('device_id', id);
  }
  // Migration/Dynamic Formatting: if the ID is a 10-digit phone number, format it as a valid UUID syntax
  if (id.length == 10 && RegExp(r'^\d+$').hasMatch(id)) {
    id = '00000000-0000-0000-0000-${id.padLeft(12, '0')}';
    box.put('device_id', id);
  }
  return id;
}

// Admin PIN - default 1234
String get adminPin {
  final box = Hive.box('settings');
  return box.get('admin_pin', defaultValue: '1234');
}

Future<void> setAdminPin(String pin) async {
  await Hive.box('settings').put('admin_pin', pin);
}

// Repository provider
final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  return CallLogRepositoryImpl(FirestoreDataSource());
});

// State notifier
class CallLogNotifier extends StateNotifier<AsyncValue<List<CallLogModel>>> {
  final CallLogRepository _repository;
  final Ref _ref;
  StreamSubscription? _subscription;

  CallLogNotifier(this._repository, this._ref) : super(const AsyncLoading()) {
    loadLogs();
    _subscribeRealtime();
    _ref.listen<TelecallerModel?>(activeUserProvider, (previous, next) {
      if (previous?.role != next?.role || previous?.phoneNumber != next?.phoneNumber) {
        _subscribeRealtime();
        loadLogs();
      }
    });
  }

  void _subscribeRealtime() {
    try {
      _subscription?.cancel();
      final activeUser = _ref.read(activeUserProvider);
      final role = activeUser?.role;
      final currentDeviceId = _ref.read(deviceIdProvider);

      Query query = FirebaseFirestore.instance.collection('call_logs');
      if (role != 'admin') {
        query = query.where('device_id', isEqualTo: currentDeviceId);
      }

      _subscription = query.snapshots().listen((snapshot) {
        try {
          final logs = snapshot.docs
              .map((doc) => CallLogModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          logs.sort((a, b) => b.date.compareTo(a.date));
          _checkTodayFollowUps(logs);
          state = AsyncData(logs);
        } catch (_) {
          loadLogs();
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _checkTodayFollowUps(List<CallLogModel> logs) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final activeUser = _ref.read(activeUserProvider);
      if (activeUser == null) return;

      final role = activeUser.role;
      final currentDeviceId = _ref.read(deviceIdProvider);
      
      final relevantLogs = role == 'admin' 
          ? logs 
          : logs.where((l) => l.deviceId == currentDeviceId).toList();

      final todayFollowUps = relevantLogs.where((l) => 
          l.connectedStatus != '__system_config__' &&
          l.nextFollowUpDate.year == today.year &&
          l.nextFollowUpDate.month == today.month &&
          l.nextFollowUpDate.day == today.day
      ).toList();

      if (todayFollowUps.isEmpty) return;

      FCMService.instance.showLocalNotification(
        id: 999,
        title: '📅 Today\'s Follow-ups Due!',
        body: role == 'admin'
            ? 'There are ${todayFollowUps.length} total follow-up calls scheduled for today.'
            : 'You have ${todayFollowUps.length} follow-up calls scheduled for today.',
        payload: 'follow_up',
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            'ht_fcm_channel',
            'HT Alerts',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> loadLogs() async {
    state = const AsyncLoading();
    try {
      final activeUser = _ref.read(activeUserProvider);
      final role = activeUser?.role;
      final currentDeviceId = _ref.read(deviceIdProvider);

      final List<CallLogModel> logs;
      if (role == 'admin') {
        logs = await _repository.getAllLogs();
      } else {
        logs = await _repository.getLogsByDeviceId(currentDeviceId);
      }
      _checkTodayFollowUps(logs);
      state = AsyncData(logs);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> addLog(CallLogModel log) async {
    try {
      await _repository.addLog(log);
      if (log.product.isNotEmpty) {
        await FirebaseFirestore.instance.collection('orders').doc(log.id).set({
          'id': log.id,
          'call_log_id': log.id,
          'customer_name': log.customerName,
          'product': log.product,
          'order_value': log.orderValue,
          'status': 'received',
          'assigned_staff_device_id': log.deviceId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Decrement stock for the new order
        await StockService.adjustStockForNewOrder(log.product);
        _ref.invalidate(productsProvider);

        // Notify Admins about the new order
        FCMService.instance.notifyAdminsOfNewOrder(
          deviceId: log.deviceId,
          customerName: log.customerName,
          product: log.product,
          orderValue: log.orderValue,
        );
      }
      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateLog(CallLogModel log) async {
    try {
      // Get the existing log first to compare products/quantities!
      final doc = await FirebaseFirestore.instance.collection('call_logs').doc(log.id).get();
      final oldProduct = doc.exists ? (doc.data()?['product'] as String? ?? '') : '';

      await _repository.updateLog(log);
      if (log.product.isNotEmpty || oldProduct.isNotEmpty) {
        final client = FirebaseFirestore.instance;
        final docRef = client.collection('orders').doc(log.id);
        final orderDoc = await docRef.get();
        final orderData = {
          'customer_name': log.customerName,
          'product': log.product,
          'order_value': log.orderValue,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (!orderDoc.exists) {
          if (log.product.isNotEmpty) {
            await docRef.set({
              'id': log.id,
              'call_log_id': log.id,
              'customer_name': log.customerName,
              'product': log.product,
              'order_value': log.orderValue,
              'status': 'received',
              'assigned_staff_device_id': log.deviceId,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

            // Adjust stock for new order document creation
            await StockService.adjustStockForNewOrder(log.product);

            // Notify Admins about the new order
            FCMService.instance.notifyAdminsOfNewOrder(
              deviceId: log.deviceId,
              customerName: log.customerName,
              product: log.product,
              orderValue: log.orderValue,
            );
          }
        } else {
          // The order already exists.
          if (log.product.isEmpty) {
            // Order was removed (e.g. products cleared or status changed)
            await docRef.delete();
            await StockService.adjustStockForOrderDeletion(oldProduct);
          } else {
            // Update order and adjust stock differences
            await docRef.update(orderData);
            await StockService.adjustStockForOrderUpdate(oldProduct, log.product);
          }
        }
        _ref.invalidate(productsProvider);
      }
      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteLog(String id) async {
    try {
      // Get the log to check if it had products
      final doc = await FirebaseFirestore.instance.collection('call_logs').doc(id).get();
      final product = doc.exists ? (doc.data()?['product'] as String? ?? '') : '';

      await FirebaseFirestore.instance.collection('orders').doc(id).delete();
      await _repository.deleteLog(id);
      
      if (product.isNotEmpty) {
        await StockService.adjustStockForOrderDeletion(product);
        _ref.invalidate(productsProvider);
      }

      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final callLogsProvider =
    StateNotifierProvider<CallLogNotifier, AsyncValue<List<CallLogModel>>>((ref) {
  return CallLogNotifier(ref.watch(callLogRepositoryProvider), ref);
});

// Staff-only logs (filtered by this device)
final staffLogsProvider = Provider<AsyncValue<List<CallLogModel>>>((ref) {
  final allLogs = ref.watch(callLogsProvider);
  final currentDeviceId = ref.watch(deviceIdProvider);
  return allLogs.whenData(
    (logs) => logs.where((l) => l.deviceId == currentDeviceId).toList(),
  );
});

// Search + filter state
class LogFilterState {
  final String searchQuery;
  final String? statusFilter;
  final bool highValueOnly;
  final bool todayOnly;
  final bool urgentFollowUp;
  final String? staffFilter; // '8019', '9698', or null
  final DateTime? dateFilter; // Date-wise filter
  final String? orderStatusFilter; // 'new_today', 'pending', 'packed_today', 'dispatched_today'

  const LogFilterState({
    this.searchQuery = '',
    this.statusFilter,
    this.highValueOnly = false,
    this.todayOnly = false,
    this.urgentFollowUp = false,
    this.staffFilter,
    this.dateFilter,
    this.orderStatusFilter,
  });

  LogFilterState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool? highValueOnly,
    bool? todayOnly,
    bool? urgentFollowUp,
    String? staffFilter,
    DateTime? dateFilter,
    String? orderStatusFilter,
    bool clearStatus = false,
    bool clearStaff = false,
    bool clearDate = false,
    bool clearOrderStatus = false,
  }) {
    return LogFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      highValueOnly: highValueOnly ?? this.highValueOnly,
      todayOnly: todayOnly ?? this.todayOnly,
      urgentFollowUp: urgentFollowUp ?? this.urgentFollowUp,
      staffFilter: clearStaff ? null : (staffFilter ?? this.staffFilter),
      dateFilter: clearDate ? null : (dateFilter ?? this.dateFilter),
      orderStatusFilter: clearOrderStatus ? null : (orderStatusFilter ?? this.orderStatusFilter),
    );
  }
}

final logFilterProvider = StateProvider<LogFilterState>((_) => const LogFilterState());

final filteredLogsProvider = Provider<List<CallLogModel>>((ref) {
  final logsAsync = ref.watch(callLogsProvider);
  final filter = ref.watch(logFilterProvider);

  return logsAsync.when(
    data: (logs) {
      var filtered = logs.where((l) => l.connectedStatus != '__system_config__').toList();

      if (filter.searchQuery.isNotEmpty) {
        final q = filter.searchQuery.toLowerCase();
        filtered = filtered
            .where((l) =>
                l.customerName.toLowerCase().contains(q) ||
                l.place.toLowerCase().contains(q) ||
                l.mobile.contains(q) ||
                l.product.toLowerCase().contains(q))
            .toList();
      }

      if (filter.statusFilter != null) {
        filtered = filtered
            .where((l) =>
                l.connectedStatus.toLowerCase() ==
                filter.statusFilter!.toLowerCase())
            .toList();
      }

      if (filter.orderStatusFilter != null) {
        final now = DateTime.now();
        filtered = filtered.where((l) {
          final status = l.orderStatus?.toLowerCase();
          final isCreatedToday = l.date.year == now.year &&
              l.date.month == now.month &&
              l.date.day == now.day;
          final isUpdatedToday = l.orderStatusUpdatedAt != null &&
              l.orderStatusUpdatedAt!.year == now.year &&
              l.orderStatusUpdatedAt!.month == now.month &&
              l.orderStatusUpdatedAt!.day == now.day;

          switch (filter.orderStatusFilter) {
            case 'new_today':
              return status == 'received' && isCreatedToday;
            case 'pending':
              return status == 'packed';
            case 'packed_today':
              return (status == 'packed' || status == 'dispatched') && isUpdatedToday;
            case 'dispatched_today':
              return status == 'dispatched' && isUpdatedToday;
            case 'exceeded_24h':
              return status == 'received' && now.difference(l.date).inHours >= 24;
            default:
              return true;
          }
        }).toList();
      }

      if (filter.highValueOnly) {
        filtered = filtered.where((l) => l.orderValue >= 1000).toList();
      }

      if (filter.todayOnly) {
        final today = DateTime.now();
        filtered = filtered
            .where((l) =>
                l.date.year == today.year &&
                l.date.month == today.month &&
                l.date.day == today.day)
            .toList();
      }

      if (filter.urgentFollowUp) {
        final now = DateTime.now();
        final dayAfter = DateTime(now.year, now.month, now.day + 2);
        filtered = filtered
            .where((l) =>
                l.nextFollowUpDate.isBefore(dayAfter) &&
                l.nextFollowUpDate.isAfter(
                    DateTime(now.year, now.month, now.day - 1)))
            .toList();
      }

      if (filter.staffFilter != null) {
        filtered = filtered
            .where((l) => l.deviceId.contains(filter.staffFilter!))
            .toList();
      }

      if (filter.dateFilter != null) {
        filtered = filtered
            .where((l) => _isSameDay(l.date, filter.dateFilter!))
            .toList();
      }

      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

// Metrics
class DashboardMetrics {
  final int todayCallCount;
  final double totalOrderValue;
  final int urgentFollowUps;

  const DashboardMetrics({
    required this.todayCallCount,
    required this.totalOrderValue,
    required this.urgentFollowUps,
  });
}

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final logsAsync = ref.watch(callLogsProvider);
  return logsAsync.when(
    data: (rawLogs) {
      final logs = rawLogs.where((l) => l.connectedStatus != '__system_config__').toList();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dayAfterTomorrow = DateTime(now.year, now.month, now.day + 2);

      final todayCalls =
          logs.where((l) => _isSameDay(l.date, today)).length;

      final totalValue =
          logs.fold<double>(0.0, (total, l) => total + l.orderValue);

      final urgent = logs
          .where((l) =>
              l.nextFollowUpDate.isAfter(today.subtract(const Duration(days: 1))) &&
              l.nextFollowUpDate.isBefore(dayAfterTomorrow))
          .length;

      return DashboardMetrics(
        todayCallCount: todayCalls,
        totalOrderValue: totalValue,
        urgentFollowUps: urgent,
      );
    },
    loading: () => const DashboardMetrics(
        todayCallCount: 0, totalOrderValue: 0, urgentFollowUps: 0),
    error: (_, _) => const DashboardMetrics(
        todayCallCount: 0, totalOrderValue: 0, urgentFollowUps: 0),
  );
});

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ── Follow-up date filter ──────────────────────────────────────────────
final followUpDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final followUpLogsProvider = Provider<List<CallLogModel>>((ref) {
  final logsAsync = ref.watch(callLogsProvider);
  final date = ref.watch(followUpDateProvider);
  return logsAsync.when(
    data: (rawLogs) {
      final logs = rawLogs.where((l) => l.connectedStatus != '__system_config__').toList();
      final filtered =
          logs.where((l) => _isSameDay(l.nextFollowUpDate, date)).toList();
      filtered.sort((a, b) => a.date.compareTo(b.date));
      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

final orderDetailProvider = Provider.family<OrderModel?, String>((ref, callLogId) {
  final ordersAsync = ref.watch(ordersProvider);
  return ordersAsync.maybeWhen(
    data: (orders) {
      final idx = orders.indexWhere((o) => o.callLogId == callLogId);
      return idx != -1 ? orders[idx] : null;
    },
    orElse: () => null,
  );
});

final staffMonthlyTargetProvider = FutureProvider<double>((ref) async {
  try {
    final now = DateTime.now();
    final currentDeviceId = ref.watch(deviceIdProvider);
    final activeUser = ref.watch(activeUserProvider);
    final userPhone = activeUser?.phoneNumber ?? '';
    final phoneDeviceId = userPhone.isNotEmpty
        ? '00000000-0000-0000-0000-${userPhone.padLeft(12, '0')}'
        : '';

    final snapshot = await FirebaseFirestore.instance
        .collection('monthly_targets')
        .where('month', isEqualTo: now.month)
        .where('year', isEqualTo: now.year)
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final targetDeviceId = data['staff_device_id'] as String?;
      final targetPhone = data['staff_phone'] as String?;

      if (targetDeviceId == currentDeviceId ||
          targetDeviceId == phoneDeviceId ||
          (userPhone.isNotEmpty && targetPhone == userPhone)) {
        final targetAmount = data['target_amount'];
        return targetAmount is num ? targetAmount.toDouble() : 0.0;
      }
    }
    return 0.0;
  } catch (_) {
    return 0.0;
  }
});

final staffMonthlyAchievementProvider = Provider<double>((ref) {
  final logsAsync = ref.watch(staffLogsProvider);
  return logsAsync.when(
    data: (logs) {
      final now = DateTime.now();
      final currentMonthLogs = logs.where((l) =>
          l.date.year == now.year &&
          l.date.month == now.month &&
          (l.orderValue > 0 || l.connectedStatus == 'Order Received'));
      return currentMonthLogs.fold<double>(0.0, (total, l) => total + l.orderValue);
    },
    loading: () => 0.0,
    error: (_, st) => 0.0,
  );
});

final staffDailyAchievementProvider = Provider<double>((ref) {
  final logsAsync = ref.watch(staffLogsProvider);
  return logsAsync.when(
    data: (logs) {
      final now = DateTime.now();
      final todayLogs = logs.where((l) =>
          l.date.year == now.year &&
          l.date.month == now.month &&
          l.date.day == now.day &&
          (l.orderValue > 0 || l.connectedStatus == 'Order Received'));
      return todayLogs.fold<double>(0.0, (total, l) => total + l.orderValue);
    },
    loading: () => 0.0,
    error: (_, st) => 0.0,
  );
});

final staffDailyTargetProvider = Provider<double>((ref) {
  final targetAsync = ref.watch(staffMonthlyTargetProvider);
  return targetAsync.maybeWhen(
    data: (target) {
      if (target <= 0) return 0.0;
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final workingDays = daysInMonth > 26 ? 26 : daysInMonth;
      return target / workingDays;
    },
    orElse: () => 0.0,
  );
});
