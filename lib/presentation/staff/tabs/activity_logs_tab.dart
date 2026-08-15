import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/call_log_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/order_providers.dart';
import '../widgets/activity_log_card.dart';

class ActivityLogsTab extends ConsumerStatefulWidget {
  const ActivityLogsTab({super.key});

  @override
  ConsumerState<ActivityLogsTab> createState() => _ActivityLogsTabState();
}

class _ActivityLogsTabState extends ConsumerState<ActivityLogsTab> {
  // null = All, 'received' = Pending, 'packed', 'dispatched'
  String? _filter;
  DateTime? _selectedDate;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  List<CallLogModel> _applyFilter(
    List<CallLogModel> logs,
    Map<String, String> orderStatusMap,
  ) {
    List<CallLogModel> filtered = logs;

    if (_selectedDate != null) {
      filtered = filtered.where((log) {
        return _isSameDay(log.date, _selectedDate);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((log) {
        return log.customerName.toLowerCase().contains(query) ||
            log.mobile.contains(query) ||
            log.place.toLowerCase().contains(query) ||
            log.remarks.toLowerCase().contains(query) ||
            log.product.toLowerCase().contains(query) ||
            log.customerResponse.toLowerCase().contains(query);
      }).toList();
    }

    if (_filter == null) return filtered;
    return filtered.where((log) {
      final status = orderStatusMap[log.id];
      switch (_filter) {
        case 'received':
          return log.product.isNotEmpty &&
              (status == null || status == 'received');
        case 'packed':
          return status == 'packed';
        case 'dispatched':
          return status == 'dispatched';
        case 'overdue':
          return log.product.isNotEmpty &&
              (status == null || status == 'received') &&
              DateTime.now().difference(log.date).inHours >= 24;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(staffLogsProvider);
    final ordersAsync = ref.watch(ordersProvider);

    final orderStatusMap = ordersAsync.maybeWhen(
      data: (orders) => {for (final o in orders) o.callLogId: o.status},
      orElse: () => <String, String>{},
    );

    return Column(
      children: [
        // ── Search & Calendar Date Bar ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search logs by name, phone, place...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textTertiary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: AppColors.textTertiary, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _pickDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedDate != null
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : (isDark ? AppColors.darkSurface : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDate != null
                            ? AppColors.primary
                            : (isDark ? AppColors.borderDark : AppColors.border),
                        width: _selectedDate != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: _selectedDate != null
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM').format(_selectedDate!),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // // ── Date Presets Row ──────────────────────────────────────────────
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        //   child: SingleChildScrollView(
        //     scrollDirection: Axis.horizontal,
        //     child: Row(
        //       children: [
        //         _DateChip(
        //           label: 'All Dates',
        //           isSelected: _selectedDate == null,
        //           onTap: () => setState(() => _selectedDate = null),
        //         ),
        //         const SizedBox(width: 6),
        //         _DateChip(
        //           label: 'Today',
        //           isSelected: _isSameDay(_selectedDate, DateTime.now()),
        //           onTap: () => setState(() => _selectedDate = DateTime.now()),
        //         ),
        //         const SizedBox(width: 6),
        //         _DateChip(
        //           label: 'Yesterday',
        //           isSelected: _isSameDay(
        //               _selectedDate, DateTime.now().subtract(const Duration(days: 1))),
        //           onTap: () => setState(() => _selectedDate =
        //               DateTime.now().subtract(const Duration(days: 1))),
        //         ),
        //         const SizedBox(width: 6),
        //         _DateChip(
        //           label: _selectedDate != null &&
        //                   !_isSameDay(_selectedDate, DateTime.now()) &&
        //                   !_isSameDay(_selectedDate,
        //                       DateTime.now().subtract(const Duration(days: 1)))
        //               ? DateFormat('dd MMM yyyy').format(_selectedDate!)
        //               : '📅 Pick Date',
        //           isSelected: _selectedDate != null &&
        //               !_isSameDay(_selectedDate, DateTime.now()) &&
        //               !_isSameDay(_selectedDate,
        //                   DateTime.now().subtract(const Duration(days: 1))),
        //           onTap: () => _pickDate(context),
        //         ),
        //         if (_selectedDate != null) ...[
        //           const SizedBox(width: 6),
        //           GestureDetector(
        //             onTap: () => setState(() => _selectedDate = null),
        //             child: Container(
        //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        //               decoration: BoxDecoration(
        //                 color: AppColors.error.withValues(alpha: 0.1),
        //                 borderRadius: BorderRadius.circular(16),
        //               ),
        //               child: Row(
        //                 mainAxisSize: MainAxisSize.min,
        //                 children: [
        //                   const Icon(Icons.close_rounded, size: 12, color: AppColors.error),
        //                   const SizedBox(width: 3),
        //                   Text(
        //                     'Clear Date',
        //                     style: GoogleFonts.plusJakartaSans(
        //                       fontSize: 11,
        //                       fontWeight: FontWeight.w600,
        //                       color: AppColors.error,
        //                     ),
        //                   ),
        //                 ],
        //               ),
        //             ),
        //           ),
        //         ],
        //       ],
        //     ),
        //   ),
        // ),

        // ── Order Status Filter chips ──────────────────────────────────────
        logsAsync.maybeWhen(
          data: (logs) => _FilterRow(
            selectedFilter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            allCount: logs.length,
            pendingCount: logs
                .where((l) =>
                    l.product.isNotEmpty &&
                    (orderStatusMap[l.id] == null ||
                        orderStatusMap[l.id] == 'received'))
                .length,
            overdueCount: logs
                .where((l) =>
                    l.product.isNotEmpty &&
                    (orderStatusMap[l.id] == null ||
                        orderStatusMap[l.id] == 'received') &&
                    DateTime.now().difference(l.date).inHours >= 24)
                .length,
            packedCount: logs
                .where((l) => orderStatusMap[l.id] == 'packed')
                .length,
            dispatchedCount: logs
                .where((l) => orderStatusMap[l.id] == 'dispatched')
                .length,
            isDark: isDark,
          ),
          orElse: () => const SizedBox.shrink(),
        ),

        // ── Log list ──────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.read(callLogsProvider.notifier).loadLogs(),
            child: logsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load activity logs',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.toString(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(callLogsProvider.notifier).loadLogs(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text('Retry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (allLogs) {
                final logs = _applyFilter(allLogs, orderStatusMap);

                if (logs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height - 320,
                        child: _EmptyState(
                          filter: _filter,
                          searchQuery: _searchQuery,
                          selectedDate: _selectedDate,
                          onClearDate: () => setState(() => _selectedDate = null),
                        ),
                      ),
                    ],
                  );
                }

                // Group by date
                final grouped = <String, List<CallLogModel>>{};
                for (final log in logs) {
                  final key = DateFormat('yyyy-MM-dd').format(log.date);
                  grouped.putIfAbsent(key, () => []).add(log);
                }
                final sortedKeys = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, i) {
                    final key = sortedKeys[i];
                    final dayLogs = grouped[key]!;
                    final date = DateTime.parse(key);
                    final isToday = _isToday(date);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppColors.primary
                                          .withValues(alpha: 0.1)
                                      : AppColors.textTertiary
                                          .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isToday
                                      ? 'Today'
                                      : DateFormat('dd MMM, EEEE')
                                          .format(date),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isToday
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Divider(
                                  color:
                                      AppColors.border.withValues(alpha: 0.6),
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${dayLogs.length} log${dayLogs.length > 1 ? 's' : ''}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...List.generate(dayLogs.length, (j) {
                          return ActivityLogCard(
                            log: dayLogs[j],
                            index: i * 5 + j,
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

// ─── Filter Row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final int allCount;
  final int pendingCount;
  final int overdueCount;
  final int packedCount;
  final int dispatchedCount;
  final bool isDark;

  const _FilterRow({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.allCount,
    required this.pendingCount,
    required this.overdueCount,
    required this.packedCount,
    required this.dispatchedCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF12151A) : const Color(0xFFF8F9FA),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: 'All',
              count: allCount,
              color: AppColors.primary,
              isSelected: selectedFilter == null,
              onTap: () => onFilterChanged(null),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Pending',
              count: pendingCount,
              color: const Color(0xFF3B82F6),
              isSelected: selectedFilter == 'received',
              onTap: () => onFilterChanged('received'),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Delayed (24h+)',
              count: overdueCount,
              color: AppColors.error,
              isSelected: selectedFilter == 'overdue',
              onTap: () => onFilterChanged('overdue'),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Packed',
              count: packedCount,
              color: const Color(0xFFF59E0B),
              isSelected: selectedFilter == 'packed',
              onTap: () => onFilterChanged('packed'),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Dispatched',
              count: dispatchedCount,
              color: AppColors.success,
              isSelected: selectedFilter == 'dispatched',
              onTap: () => onFilterChanged('dispatched'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : color.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String? filter;
  final String searchQuery;
  final DateTime? selectedDate;
  final VoidCallback? onClearDate;

  const _EmptyState({
    this.filter,
    this.searchQuery = '',
    this.selectedDate,
    this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSearching = searchQuery.isNotEmpty;
    final bool isDateFiltered = selectedDate != null;

    final String message = isDateFiltered
        ? 'No logs on ${DateFormat('dd MMM yyyy').format(selectedDate!)}'
        : isSearching
            ? 'No results found'
            : switch (filter) {
                'received' => 'No pending orders',
                'overdue' => 'No 24h+ delayed orders',
                'packed' => 'No packed orders yet',
                'dispatched' => 'No dispatched orders yet',
                _ => 'No activity yet',
              };

    final String sub = isDateFiltered
        ? 'Try selecting a different date or clear the date filter.'
        : isSearching
            ? 'No logs match "$searchQuery".\nTry a different name, phone, or place.'
            : switch (filter) {
                'received' => 'Orders waiting to be packed will appear here.',
                'overdue' => 'Orders pending for over 24 hours without being packed or dispatched will appear here.',
                'packed' => 'Mark orders as packed to see them here.',
                'dispatched' => 'Dispatched orders will appear here.',
                _ => 'Your call logs will appear here\nonce you start logging.',
              };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (isSearching || isDateFiltered
                      ? AppColors.textTertiary
                      : AppColors.primary)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isDateFiltered
                  ? Icons.calendar_today_rounded
                  : (isSearching
                      ? Icons.search_off_rounded
                      : Icons.timeline_rounded),
              color: isSearching || isDateFiltered
                  ? AppColors.textTertiary
                  : AppColors.primary,
              size: 40,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ).animate().fadeIn(delay: 300.ms),
          if (isDateFiltered && onClearDate != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClearDate,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Show All Dates',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
