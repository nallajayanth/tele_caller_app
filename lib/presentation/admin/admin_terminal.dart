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
import '../../data/models/call_log_model.dart';
import '../../providers/call_log_providers.dart';
import '../../providers/deleted_log_providers.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_providers.dart';
import '../common/screens/followup_filter_screen.dart';
import '../common/widgets/success_toast.dart';
import 'screens/bin_screen.dart';
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
  final _pageCtrl = PageController();
  int _metricPage = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pageCtrl.dispose();
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
            l.product,
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

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final metrics = ref.watch(dashboardMetricsProvider);
    final filter = ref.watch(logFilterProvider);
    final filteredLogs = ref.watch(filteredLogsProvider);
    final binCount = ref.watch(deletedLogProvider).length;

    final logsAsync = ref.watch(callLogsProvider);
    final logs = logsAsync.value ?? [];
    final now = DateTime.now();
    final todayLogs = logs.where((l) =>
        l.date.year == now.year &&
        l.date.month == now.month &&
        l.date.day == now.day).toList();
    final staff1Count = todayLogs.where((l) => l.deviceId.contains('8019176176')).length;
    final staff2Count = todayLogs.where((l) => l.deviceId.contains('9698176176')).length;

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
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Sign Out',
          icon: const Icon(Icons.logout_rounded, size: 20),
          onPressed: () => _confirmSignOut(context, ref),
        ),
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
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 22,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          // Recycle Bin with badge
          IconButton(
            tooltip: 'Recycle Bin',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BinScreen()),
            ),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: binCount > 0
                        ? AppColors.error.withValues(alpha: 0.12)
                        : AppColors.textTertiary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: binCount > 0 ? AppColors.error : AppColors.textTertiary,
                    size: 18,
                  ),
                ),
                if (binCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        binCount > 9 ? '9+' : '$binCount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_rounded,
                  color: AppColors.primary, size: 18),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FollowUpFilterScreen(isAdmin: true),
              ),
            ),
            tooltip: 'Follow-up Tracker',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.ios_share_rounded,
                  color: Colors.white, size: 18),
            ),
            onPressed: _exportCSV,
            tooltip: 'Export to CSV',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Metrics carousel
                SizedBox(
                  height: 185,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _pageCtrl,
                          onPageChanged: (i) => setState(() => _metricPage = i),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: MetricTile(
                                title: "Today's Calls",
                                value: metrics.todayCallCount.toString(),
                                subtitle: 'Logged today',
                                icon: Icons.call_rounded,
                                gradientColors: const [Color(0xFF005F54), Color(0xFF00857A)],
                                index: 0,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: MetricTile(
                                title: 'Total Order Value',
                                value: _fmtValue(metrics.totalOrderValue),
                                subtitle: 'Cumulative ₹',
                                icon: Icons.currency_rupee_rounded,
                                gradientColors: const [Color(0xFFD97706), Color(0xFFB45309)],
                                index: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: MetricTile(
                                title: 'Urgent Follow-ups',
                                value: metrics.urgentFollowUps.toString(),
                                subtitle: 'Today & tomorrow',
                                icon: Icons.notifications_active_rounded,
                                gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                                index: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _metricPage == i ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _metricPage == i
                                  ? AppColors.primary
                                  : AppColors.textTertiary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // Staff performance today cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StaffPerformanceCard(
                          name: '8019',
                          phone: '8019176176',
                          count: staff1Count,
                          isActive: filter.staffFilter == '8019',
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            final isSelected = filter.staffFilter == '8019';
                            ref.read(logFilterProvider.notifier).update(
                                  (s) => s.copyWith(
                                    staffFilter: isSelected ? null : '8019',
                                    clearStaff: isSelected,
                                  ),
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StaffPerformanceCard(
                          name: '9698',
                          phone: '9698176176',
                          count: staff2Count,
                          isActive: filter.staffFilter == '9698',
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            final isSelected = filter.staffFilter == '9698';
                            ref.read(logFilterProvider.notifier).update(
                                  (s) => s.copyWith(
                                    staffFilter: isSelected ? null : '9698',
                                    clearStaff: isSelected,
                                  ),
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

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
                            Row(
                              children: [
                                Icon(Icons.analytics_rounded,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  filter.dateFilter == null
                                      ? 'All-Time Business Summary'
                                      : 'Business Summary (${DateFormat('dd MMM yyyy').format(filter.dateFilter!)})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
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
                  childCount: filteredLogs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtValue(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
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

class _StaffPerformanceCard extends StatelessWidget {
  final String name;
  final String phone;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _StaffPerformanceCard({
    required this.name,
    required this.phone,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = name == '8019' ? const Color(0xFF00857A) : const Color(0xFFD97706);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive 
              ? primaryColor 
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive 
                ? primaryColor 
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: isActive ? 2 : 1.2,
          ),
          boxShadow: isActive 
              ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Avatar with initials
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive 
                    ? Colors.white.withValues(alpha: 0.2) 
                    : primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name == '8019' ? '80' : '96',
                  style: GoogleFonts.plusJakartaSans(
                    color: isActive ? Colors.white : primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Staff details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: isActive ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Calls Today',
                    style: GoogleFonts.plusJakartaSans(
                      color: isActive 
                          ? Colors.white.withValues(alpha: 0.75) 
                          : AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Call counter badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  color: isActive ? primaryColor : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).slideX(begin: name == '8019' ? -0.06 : 0.06);
  }
}
