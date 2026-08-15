import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/product_formatter.dart';
import '../../data/models/call_log_model.dart';
import '../../providers/call_log_providers.dart';
import '../../providers/deleted_log_providers.dart';
import '../../providers/theme_provider.dart';
import '../../providers/order_providers.dart';
import '../../providers/auth_providers.dart';

import '../common/widgets/success_toast.dart';
import 'screens/bin_screen.dart';
import 'screens/target_management_screen.dart';
import 'screens/sales_analytics_screen.dart';
import 'screens/employee_monitoring_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/product_management_screen.dart';
import 'screens/live_tracking_screen.dart';
import 'views/admin_edit_modal.dart';
import 'widgets/admin_log_card.dart';
import 'widgets/metric_tile.dart';


class AdminTerminal extends ConsumerStatefulWidget {
  const AdminTerminal({super.key});

  @override
  ConsumerState<AdminTerminal> createState() => _AdminTerminalState();
}

class _AdminTerminalState extends ConsumerState<AdminTerminal> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _currentIndex = 0;
  int _displayLimit = 30;
  LogFilterState? _lastFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCSV() async {
    final logsAsync = ref.read(callLogsProvider);
    final logs = logsAsync.value ?? [];
    if (logs.isEmpty) {
      SuccessToast.show(context,
          message: 'No data to export.',
          icon: Icons.info_outline_rounded,
          color: AppColors.info);
      return;
    }

    final rows = <List<dynamic>>[
      [
        'Date',
        'Customer Name',
        'Mobile',
        'Place',
        'Product',
        'Status',
        'Response',
        'Next Follow-up',
        'Order Value',
        'Remarks',
      ],
      ...logs.map((l) => [
            DateFormat('dd/MM/yyyy HH:mm').format(l.date),
            l.customerName,
            l.mobile,
            l.place,
            ProductFormatter.format(l.product),
            l.connectedStatus,
            l.customerResponse,
            DateFormat('dd/MM/yyyy').format(l.nextFollowUpDate),
            l.orderValue.toStringAsFixed(2),
            l.remarks,
          ]),
    ];

    const converter = ListToCsvConverter();
    final csv = converter.convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'MedTrac_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'MedTrac Pro — Business Report',
      text: 'Exported ${logs.length} call logs from MedTrac Pro.',
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout_rounded,
              color: AppColors.error, size: 28),
        ),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Are you sure you want to sign out from HT TELECALING?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: Text('Sign Out',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      await ref.read(activeUserProvider.notifier).signOut();
      // Reload logs to clear memory session isolation
      await ref.read(callLogsProvider.notifier).loadLogs();
    }
  }

  void _onPipelineCardTapped(String type) {
    HapticFeedback.mediumImpact();
    final currentFilter = ref.read(logFilterProvider);
    final isSelected = currentFilter.orderStatusFilter == type;

    ref.read(logFilterProvider.notifier).update((s) => s.copyWith(
          orderStatusFilter: isSelected ? null : type,
          clearStatus: true, // clear other filters to focus on orders
          clearOrderStatus: isSelected, // clear if de-selected
        ));

    if (!isSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            480.0, // scroll offset down to filtered logs list
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final metrics = ref.watch(dashboardMetricsProvider);
    final filter = ref.watch(logFilterProvider);
    if (_lastFilter != filter) {
      _displayLimit = 30;
      _lastFilter = filter;
    }
    final filteredLogs = ref.watch(filteredLogsProvider);
    final binCount = ref.watch(deletedLogProvider).length;
    final dailyStats = ref.watch(globalOrderStatsProvider);

    final logsAsync = ref.watch(callLogsProvider);
    final logs = (logsAsync.value ?? []).where((l) => l.connectedStatus != '__system_config__').toList();

    final selectedDate = filter.dateFilter;
    final dateLogs = selectedDate == null 
        ? logs 
        : logs.where((l) => 
            l.date.year == selectedDate.year &&
            l.date.month == selectedDate.month &&
            l.date.day == selectedDate.day).toList();

    final totalSalesForDate = dateLogs.fold<double>(0.0, (sum, l) => sum + l.orderValue);
    final totalCollectionForDate = dateLogs
        .where((l) => l.connectedStatus.toLowerCase() == 'connected')
        .fold<double>(0.0, (sum, l) => sum + l.orderValue);

    return Scaffold(
      appBar: _currentIndex == 0 ? AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Terminal', style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Full business control',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.error, size: 18),
            ),
            onPressed: () => _confirmSignOut(context, ref),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'export') {
                _exportCSV();
              } else if (value == 'deleted') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BinScreen()),
                );
              } else if (value == 'theme') {
                ref.read(themeModeProvider.notifier).toggle();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Export to CSV',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'deleted',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Recently Deleted',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isDark ? 'Light Mode' : 'Dark Mode',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ) : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(callLogsProvider.notifier).loadLogs();
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Metrics carousel
                // Today's Calls Metric Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    height: 155,
                    child: MetricTile(
                      title: "Today's Calls",
                      value: metrics.todayCallCount.toString(),
                      subtitle: 'Logged today',
                      icon: Icons.call_rounded,
                      gradientColors: const [Color(0xFF005F54), Color(0xFF00857A)],
                      index: 0,
                    ),
                  ),
                ),

                const SizedBox.shrink(),

                // Today's Order Pipeline Stats Dashboard
                _buildDailyOrderStats(context, isDark, dailyStats, filter),

                const SizedBox.shrink(),

                // Date-wise Summary Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.analytics_rounded,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      filter.dateFilter == null
                                          ? 'All-Time Business Summary'
                                          : 'Business Summary (${DateFormat('dd MMM yyyy').format(filter.dateFilter!)})',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Date Selector Button
                            Row(
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: filter.dateFilter ?? DateTime.now(),
                                      firstDate: DateTime(2025),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
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
                                      ref.read(logFilterProvider.notifier).update(
                                            (s) => s.copyWith(dateFilter: picked),
                                          );
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_month_rounded,
                                      size: 14, color: AppColors.primary),
                                  label: Text(
                                    filter.dateFilter == null
                                        ? 'Pick Date'
                                        : DateFormat('dd/MM').format(filter.dateFilter!),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (filter.dateFilter != null) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      ref.read(logFilterProvider.notifier).update(
                                            (s) => s.copyWith(clearDate: true),
                                          );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 12,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Stats row
                        Row(
                          children: [
                            // Total Sales
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.accent.withValues(alpha: 0.05),
                                      AppColors.accent.withValues(alpha: 0.12),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL SALES',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accent,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _fmtValue(totalSalesForDate),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Total Collection
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF00857A).withValues(alpha: 0.05),
                                      const Color(0xFF00857A).withValues(alpha: 0.12),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF00857A).withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL COLLECTION',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF00857A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _fmtValue(totalCollectionForDate),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF00857A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (q) => ref.read(logFilterProvider.notifier).update(
                          (s) => s.copyWith(searchQuery: q),
                        ),
                    decoration: InputDecoration(
                      hintText: 'Search name, place, mobile...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: filter.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(logFilterProvider.notifier)
                                    .update((s) => s.copyWith(searchQuery: ''));
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ),

                // Filter pills
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _FilterPill(
                        label: 'All',
                        isActive: filter.statusFilter == null &&
                            !filter.highValueOnly &&
                            !filter.todayOnly &&
                            !filter.urgentFollowUp &&
                            filter.dateFilter == null,
                        onTap: () => ref.read(logFilterProvider.notifier).update(
                              (_) => const LogFilterState(),
                            ),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: '📅 Today',
                        isActive: filter.todayOnly,
                        color: AppColors.info,
                        onTap: () => ref
                            .read(logFilterProvider.notifier)
                            .update((s) => s.copyWith(todayOnly: !s.todayOnly)),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: '🔔 Urgent',
                        isActive: filter.urgentFollowUp,
                        color: AppColors.error,
                        onTap: () => ref
                            .read(logFilterProvider.notifier)
                            .update((s) => s.copyWith(urgentFollowUp: !s.urgentFollowUp)),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: '💰 High Value',
                        isActive: filter.highValueOnly,
                        color: AppColors.accent,
                        onTap: () => ref
                            .read(logFilterProvider.notifier)
                            .update((s) => s.copyWith(highValueOnly: !s.highValueOnly)),
                      ),
                      const SizedBox(width: 8),
                      ...['Connected', 'Busy', 'No Answer', 'Interested', 'Not Interested', 'Call Back']
                          .map((status) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FilterPill(
                                  label: status,
                                  isActive: filter.statusFilter == status,
                                  color: AppColors.statusColor(status),
                                  onTap: () => ref
                                      .read(logFilterProvider.notifier)
                                      .update((s) => s.copyWith(
                                            statusFilter: status,
                                            clearStatus: s.statusFilter == status,
                                          )),
                                ),
                              )),
                    ],
                  ),
                ),

                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${filteredLogs.length} records',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Log list (SliverList)
          if (filteredLogs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyFiltered(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i == _displayLimit) {
                      final remaining = filteredLogs.length - _displayLimit;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        child: Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _displayLimit += 30;
                              });
                            },
                            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                            label: Text(
                              'Load More ($remaining remaining)',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final log = filteredLogs[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SwipeableLogCard(
                        key: ValueKey(log.id),
                        log: log,
                        index: i,
                      ),
                    );
                  },
                  childCount: filteredLogs.length > _displayLimit
                      ? _displayLimit + 1
                      : filteredLogs.length,
                ),
              ),
            ),
        ],
      ),
    ),
          const LiveTrackingScreen(),
          const SalesAnalyticsScreen(),
          _AdminSettingsTab(binCount: binCount),
        ],
      ),
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }

  String _fmtValue(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }



  Widget _buildDailyOrderStats(BuildContext context, bool isDark, OrderPipelineStats stats, LogFilterState filter) {
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S ORDER PIPELINE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: _OrderStatCard(
                    label: 'New Today',
                    value: stats.newOrdersCount.toString(),
                    color: const Color(0xFF3B82F6),
                    icon: Icons.new_releases_rounded,
                    isDark: isDark,
                    cardColor: cardColor,
                    isSelected: filter.orderStatusFilter == 'new_today',
                    onTap: () => _onPipelineCardTapped('new_today'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: _OrderStatCard(
                    label: 'Pending',
                    value: stats.pendingDispatch.toString(),
                    color: const Color(0xFFF59E0B),
                    icon: Icons.pending_actions_rounded,
                    isDark: isDark,
                    cardColor: cardColor,
                    isSelected: filter.orderStatusFilter == 'pending',
                    onTap: () => _onPipelineCardTapped('pending'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: _OrderStatCard(
                    label: 'Packed',
                    value: stats.packedCount.toString(),
                    color: const Color(0xFF8B5CF6),
                    icon: Icons.inventory_2_rounded,
                    isDark: isDark,
                    cardColor: cardColor,
                    isSelected: filter.orderStatusFilter == 'packed_today',
                    onTap: () => _onPipelineCardTapped('packed_today'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: _OrderStatCard(
                    label: 'Dispatched',
                    value: stats.dispatchedCount.toString(),
                    color: const Color(0xFF10B981),
                    icon: Icons.local_shipping_rounded,
                    isDark: isDark,
                    cardColor: cardColor,
                    isSelected: filter.orderStatusFilter == 'dispatched_today',
                    onTap: () => _onPipelineCardTapped('dispatched_today'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: _OrderStatCard(
                    label: 'Exceeded 24h',
                    value: stats.exceeded24h.toString(),
                    color: AppColors.error,
                    icon: Icons.warning_amber_rounded,
                    isDark: isDark,
                    cardColor: cardColor,
                    isSelected: filter.orderStatusFilter == 'exceeded_24h',
                    onTap: () => _onPipelineCardTapped('exceeded_24h'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;
  final Color cardColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
    required this.cardColor,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? AppShadows.primaryGlow(color)
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate(target: isSelected ? 1.0 : 0.0)
     .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.05, 1.05), duration: 150.ms);
  }
}


class _SwipeableLogCard extends ConsumerWidget {
  final CallLogModel log;
  final int index;

  const _SwipeableLogCard({super.key, required this.log, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('dismiss_${log.id}'),
      background: _buildEditBg(),
      secondaryBackground: _buildDeleteBg(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          _openEdit(context);
          return false;
        } else {
          HapticFeedback.mediumImpact();
          return await _confirmMoveToBin(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _softDelete(context, ref);
        }
      },
      child: AdminLogCard(
        log: log,
        index: index,
        onEdit: () => _openEdit(context),
        onDelete: () => _handleDeleteTap(context, ref),
      ),
    );
  }

  void _softDelete(BuildContext context, WidgetRef ref) {
    ref.read(deletedLogProvider.notifier).moveToBin(log);
    ref.read(callLogsProvider.notifier).deleteLog(log.id);
    SuccessToast.show(
      context,
      message: 'Moved to Recycle Bin.',
      icon: Icons.delete_sweep_rounded,
      color: AppColors.error,
    );
  }

  Future<void> _handleDeleteTap(BuildContext context, WidgetRef ref) async {
    final confirm = await _confirmMoveToBin(context);
    if (confirm && context.mounted) {
      _softDelete(context, ref);
    }
  }

  Widget _buildEditBg() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            'Edit',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteBg() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Move to Bin',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminEditModal(log: log),
    );
  }

  Future<bool> _confirmMoveToBin(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_sweep_rounded,
              color: AppColors.error, size: 28),
        ),
        title: Text(
          'Move to Bin?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'The log for "${log.customerName}" will be moved to the Recycle Bin and permanently deleted after 30 days.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: Text('Move to Bin',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isActive,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.25),
            width: isActive ? 0 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _EmptyFiltered extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            'No matching records',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filters.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}



class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AdminBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _AdminNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _AdminNavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Live Map',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _AdminNavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Analytics',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _AdminNavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Settings',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _AdminNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSettingsTab extends StatelessWidget {
  final int binCount;

  const _AdminSettingsTab({required this.binCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Settings',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsTile(
            context: context,
            title: 'Targets',
            subtitle: 'Configure employee monthly targets',
            icon: Icons.track_changes_rounded,
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TargetManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            context: context,
            title: 'Monitoring',
            subtitle: 'Track employee call and shift status',
            icon: Icons.people_rounded,
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmployeeMonitoringScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            context: context,
            title: 'Employees',
            subtitle: 'Manage roles and credentials',
            icon: Icons.manage_accounts_rounded,
            color: AppColors.primary,
            isDark: isDark,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            context: context,
            title: 'Products',
            subtitle: 'Manage items catalog and stock levels',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductManagementScreen()),
            ),
          ),

          const SizedBox(height: 12),
          _buildSettingsTile(
            context: context,
            title: 'Recycle Bin',
            subtitle: 'Recently deleted call logs',
            icon: Icons.delete_outline_rounded,
            color: AppColors.error,
            isDark: isDark,
            badgeCount: binCount,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BinScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final showBadge = badgeCount != null && badgeCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (showBadge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}
