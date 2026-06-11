import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/datasources/supabase_datasource.dart';
import '../data/models/call_log_model.dart';
import '../data/repositories/call_log_repository_impl.dart';
import '../domain/repositories/call_log_repository.dart';

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

  CallLogNotifier(this._repository) : super(const AsyncLoading()) {
    loadLogs();
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
      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateLog(CallLogModel log) async {
    try {
      await _repository.updateLog(log);
      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteLog(String id) async {
    try {
      await _repository.deleteLog(id);
      await loadLogs();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final callLogsProvider =
    StateNotifierProvider<CallLogNotifier, AsyncValue<List<CallLogModel>>>((ref) {
  return CallLogNotifier(ref.watch(callLogRepositoryProvider));
});

// Staff-only logs (filtered by this device)
final staffLogsProvider = Provider<AsyncValue<List<CallLogModel>>>((ref) {
  final allLogs = ref.watch(callLogsProvider);
  final currentDeviceId = deviceId;
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

  const LogFilterState({
    this.searchQuery = '',
    this.statusFilter,
    this.highValueOnly = false,
    this.todayOnly = false,
    this.urgentFollowUp = false,
    this.staffFilter,
    this.dateFilter,
  });

  LogFilterState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool? highValueOnly,
    bool? todayOnly,
    bool? urgentFollowUp,
    String? staffFilter,
    DateTime? dateFilter,
    bool clearStatus = false,
    bool clearStaff = false,
    bool clearDate = false,
  }) {
    return LogFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      highValueOnly: highValueOnly ?? this.highValueOnly,
      todayOnly: todayOnly ?? this.todayOnly,
      urgentFollowUp: urgentFollowUp ?? this.urgentFollowUp,
      staffFilter: clearStaff ? null : (staffFilter ?? this.staffFilter),
      dateFilter: clearDate ? null : (dateFilter ?? this.dateFilter),
    );
  }
}

final logFilterProvider = StateProvider<LogFilterState>((_) => const LogFilterState());

final filteredLogsProvider = Provider<List<CallLogModel>>((ref) {
  final logsAsync = ref.watch(callLogsProvider);
  final filter = ref.watch(logFilterProvider);

  return logsAsync.when(
    data: (logs) {
      var filtered = logs;

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
        final phonePart = filter.staffFilter == '8019' ? '8019176176' : '9698176176';
        filtered = filtered
            .where((l) => l.deviceId.contains(phonePart))
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
    data: (logs) {
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
    data: (logs) {
      final filtered =
          logs.where((l) => _isSameDay(l.nextFollowUpDate, date)).toList();
      filtered.sort((a, b) => a.date.compareTo(b.date));
      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});
