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
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CallLogModel> _applyFilter(
    List<CallLogModel> logs,
    Map<String, String> orderStatusMap,
  ) {
    List<CallLogModel> filtered = logs;

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
        // ── Search bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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

        // ── Filter chips ──────────────────────────────────────────────────
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
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allLogs) {
                final logs = _applyFilter(allLogs, orderStatusMap);

                if (logs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height - 280,
                        child: _EmptyState(filter: _filter, searchQuery: _searchQuery),
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
  final int packedCount;
  final int dispatchedCount;
  final bool isDark;

  const _FilterRow({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.allCount,
    required this.pendingCount,
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
  const _EmptyState({this.filter, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final bool isSearching = searchQuery.isNotEmpty;
    final String message = isSearching
        ? 'No results found'
        : switch (filter) {
            'received' => 'No pending orders',
            'packed' => 'No packed orders yet',
            'dispatched' => 'No dispatched orders yet',
            _ => 'No activity yet',
          };
    final String sub = isSearching
        ? 'No logs match "$searchQuery".\nTry a different name, phone, or place.'
        : switch (filter) {
            'received' => 'Orders waiting to be packed will appear here.',
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
              color: (isSearching ? AppColors.textTertiary : AppColors.primary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isSearching ? Icons.search_off_rounded : Icons.timeline_rounded,
              color: isSearching ? AppColors.textTertiary : AppColors.primary,
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
        ],
      ),
    );
  }
}
