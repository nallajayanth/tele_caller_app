import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/datasources/supabase_datasource.dart';
import '../data/models/call_log_model.dart';
import '../data/models/order_model.dart';
import '../data/repositories/call_log_repository_impl.dart';
import '../domain/repositories/call_log_repository.dart';
import 'auth_providers.dart';
import 'order_providers.dart';

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
  return CallLogRepositoryImpl(SupabaseDataSource());
});

// State notifier
class CallLogNotifier extends StateNotifier<AsyncValue<List<CallLogModel>>> {
  final CallLogRepository _repository;
  RealtimeChannel? _subscription;

  CallLogNotifier(this._repository) : super(const AsyncLoading()) {
    loadLogs();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    try {
      _subscription = Supabase.instance.client
          .channel('public:call_logs')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'call_logs',
            callback: (PostgresChangePayload payload) {
              _handleRealtimeChange(payload);
            },
          );
      _subscription?.subscribe();
    } catch (_) {}
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    state.whenData((currentLogs) {
      final list = List<CallLogModel>.from(currentLogs);
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      if (payload.eventType == PostgresChangeEvent.insert) {
        if (newRecord.isNotEmpty) {
          final log = CallLogModel.fromJson(newRecord);
          if (!list.any((l) => l.id == log.id)) {
            list.insert(0, log);
            list.sort((a, b) => b.date.compareTo(a.date));
            state = AsyncData(list);
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        if (newRecord.isNotEmpty) {
          final log = CallLogModel.fromJson(newRecord);
          final idx = list.indexWhere((l) => l.id == log.id);
          if (idx != -1) {
            list[idx] = log;
          } else {
            list.add(log);
          }
          list.sort((a, b) => b.date.compareTo(a.date));
          state = AsyncData(list);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        if (oldRecord.isNotEmpty) {
          final id = oldRecord['id'] as String?;
          if (id != null) {
            list.removeWhere((l) => l.id == id);
            state = AsyncData(list);
          }
        }
      }
    });
  }

  Future<void> loadLogs() async {
    state = const AsyncLoading();
    try {
      final logs = await _repository.getAllLogs();
      state = AsyncData(logs);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> addLog(CallLogModel log) async {
    try {
      await _repository.addLog(log);
      if (log.product.isNotEmpty) {
        await Supabase.instance.client.from('orders').insert({
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
      }
      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateLog(CallLogModel log) async {
    try {
      await _repository.updateLog(log);
      if (log.product.isNotEmpty) {
        final client = Supabase.instance.client;
        final existing = await client.from('orders').select('id').eq('id', log.id).maybeSingle();
        final orderData = {
          'customer_name': log.customerName,
          'product': log.product,
          'order_value': log.orderValue,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (existing == null) {
          await client.from('orders').insert({
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
        } else {
          await client.from('orders').update(orderData).eq('id', log.id);
        }
      }
      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteLog(String id) async {
    try {
      await Supabase.instance.client.from('orders').delete().eq('id', id);
      await _repository.deleteLog(id);
      await loadLogs();
      return true;
    } catch (_) {
      return false;
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

final callLogsProvider =
    StateNotifierProvider<CallLogNotifier, AsyncValue<List<CallLogModel>>>((ref) {
  return CallLogNotifier(ref.watch(callLogRepositoryProvider));
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
          logs.fold<double>(0.0, (sum, l) => sum + l.orderValue);

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
    final response = await Supabase.instance.client
        .from('monthly_targets')
        .select('target_amount')
        .eq('staff_device_id', currentDeviceId)
        .eq('month', now.month)
        .eq('year', now.year)
        .maybeSingle();
    
    if (response == null) return 0.0;
    return (response['target_amount'] as num).toDouble();
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
          l.connectedStatus == 'Order Received');
      return currentMonthLogs.fold<double>(0.0, (sum, l) => sum + l.orderValue);
    },
    loading: () => 0.0,
    error: (_, st) => 0.0,
  );
});
