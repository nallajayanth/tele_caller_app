import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/pdf_analytics_exporter.dart';
import '../../../data/models/call_log_model.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/order_providers.dart';

class PerformanceTab extends ConsumerStatefulWidget {
  const PerformanceTab({super.key});

  @override
  ConsumerState<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends ConsumerState<PerformanceTab> {
  int _selectedTab = 0; // 0 = Daily Performance, 1 = Monthly Performance
  bool _isExporting = false;

  Future<void> _exportPdf({
    required bool isDaily,
    required double target,
    required double achieved,
    required String periodTitle,
  }) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      final activeUser = ref.read(activeUserProvider);
      final staffName = activeUser?.name ?? 'Staff';
      final pipelineStats = isDaily
          ? ref.read(staffOrderStatsProvider)
          : ref.read(staffMonthlyOrderStatsProvider);
      final logsAsync = ref.read(staffLogsProvider);

      final now = DateTime.now();
      final remaining = (target - achieved) > 0 ? (target - achieved) : 0.0;
      final percent = target > 0
          ? (achieved / target).clamp(0.0, 1.0)
          : (achieved > 0 ? 1.0 : 0.0);

      List<CallLogModel> filteredLogs = [];
      logsAsync.whenData((logs) {
        if (isDaily) {
          filteredLogs = logs
              .where((l) =>
                  l.date.year == now.year &&
                  l.date.month == now.month &&
                  l.date.day == now.day)
              .toList();
        } else {
          filteredLogs = logs
              .where(
                  (l) => l.date.year == now.year && l.date.month == now.month)
              .toList();
        }
      });

      await PdfAnalyticsExporter.exportAnalyticsPdf(
        staffName: staffName,
        isDaily: isDaily,
        periodTitle: periodTitle,
        target: target,
        achieved: achieved,
        remaining: remaining,
        percent: percent,
        pipelineStats: pipelineStats,
        logs: filteredLogs,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthlyTargetAsync = ref.watch(staffMonthlyTargetProvider);
    final monthlyAchievement = ref.watch(staffMonthlyAchievementProvider);
    final dailyTarget = ref.watch(staffDailyTargetProvider);
    final dailyAchievement = ref.watch(staffDailyAchievementProvider);
    final dailyStats = ref.watch(staffOrderStatsProvider);
    final monthlyStats = ref.watch(staffMonthlyOrderStatsProvider);

    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy').format(now);
    final monthStr = DateFormat('MMMM yyyy').format(now);

    return monthlyTargetAsync.when(
      data: (monthlyTarget) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Segmented Tab Switcher (Daily vs Monthly) ──────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: '☀️ Daily',
                      isSelected: _selectedTab == 0,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 0);
                      },
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: '📅 Monthly',
                      isSelected: _selectedTab == 1,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = 1);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Content based on selected tab ─────────────────────────────
            if (_selectedTab == 0) ...[
              // ☀️ DAILY PERFORMANCE CONTENT
              _buildHeader(
                isDark: isDark,
                badgeText: 'TODAY\'S ANALYTICS',
                title: 'Daily Performance ($dateStr)',
                icon: Icons.today_rounded,
                onExportPdf: () => _exportPdf(
                  isDaily: true,
                  target: dailyTarget,
                  achieved: dailyAchievement,
                  periodTitle: 'Daily Performance Report ($dateStr)',
                ),
              ),
              const SizedBox(height: 16),
              _buildOrderPipeline(
                context: context,
                isDark: isDark,
                stats: dailyStats,
                isDaily: true,
              ),
              const SizedBox(height: 16),
              _buildPerformanceCircleCard(
                context: context,
                isDark: isDark,
                title: 'DAILY TARGET & ACHIEVEMENT',
                targetAmount: dailyTarget,
                achievedAmount: dailyAchievement,
                badgeText: 'Daily Goal',
                onDownloadPdf: () => _exportPdf(
                  isDaily: true,
                  target: dailyTarget,
                  achieved: dailyAchievement,
                  periodTitle: 'Daily Performance Report ($dateStr)',
                ),
              ),
            ] else ...[
              // 📅 MONTHLY PERFORMANCE CONTENT
              _buildHeader(
                isDark: isDark,
                badgeText: monthStr.toUpperCase(),
                title: 'Monthly Sales Performance',
                icon: Icons.analytics_rounded,
                onExportPdf: () => _exportPdf(
                  isDaily: false,
                  target: monthlyTarget,
                  achieved: monthlyAchievement,
                  periodTitle: 'Monthly Sales Performance Report ($monthStr)',
                ),
              ),
              const SizedBox(height: 16),
              _buildOrderPipeline(
                context: context,
                isDark: isDark,
                stats: monthlyStats,
                isDaily: false,
              ),
              const SizedBox(height: 16),
              _buildPerformanceCircleCard(
                context: context,
                isDark: isDark,
                title: 'MONTHLY TARGET & ACHIEVEMENT',
                targetAmount: monthlyTarget,
                achievedAmount: monthlyAchievement,
                badgeText: 'Monthly Goal',
                onDownloadPdf: () => _exportPdf(
                  isDaily: false,
                  target: monthlyTarget,
                  achieved: monthlyAchievement,
                  periodTitle: 'Monthly Sales Performance Report ($monthStr)',
                ),
              ),
              if (monthlyTarget == 0) ...[
                const SizedBox(height: 16),
                _buildTargetNotSetWarning(isDark),
              ],
            ],
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error loading targets: $e')),
    );
  }

  Widget _buildHeader({
    required bool isDark,
    required String badgeText,
    required String title,
    required IconData icon,
    required VoidCallback onExportPdf,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onExportPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'PDF',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCircleCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required double targetAmount,
    required double achievedAmount,
    required String badgeText,
    required VoidCallback onDownloadPdf,
  }) {
    final remaining = (targetAmount - achievedAmount) > 0
        ? (targetAmount - achievedAmount)
        : 0.0;
    final double percent = targetAmount > 0
        ? (achievedAmount / targetAmount).clamp(0.0, 1.0)
        : (achievedAmount > 0 ? 1.0 : 0.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1.5,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Circular Progress Visualizer ──────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 14,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  color: percent >= 1.0 ? AppColors.success : AppColors.primary,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(percent * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: percent >= 1.0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                  Text(
                    'Achieved',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Target vs Achievement Metrics ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  title: 'TARGET',
                  value: '₹${_formatAmount(targetAmount)}',
                  icon: Icons.flag_rounded,
                  color: AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: _MetricItem(
                  title: 'ACHIEVED',
                  value: '₹${_formatAmount(achievedAmount)}',
                  icon: Icons.stars_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          // ── Remaining Target ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REMAINING TARGET',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining > 0
                          ? '₹${_formatFull(remaining)}'
                          : '🎉 Target Achieved!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: remaining > 0
                            ? AppColors.accent
                            : AppColors.success,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: remaining > 0
                      ? AppColors.accent.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  remaining > 0
                      ? Icons.trending_up_rounded
                      : Icons.workspace_premium_rounded,
                  color: remaining > 0 ? AppColors.accent : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

        ],
      ),
    );
  }

  Widget _buildTargetNotSetWarning(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Monthly target has not been set by the Admin yet. Please request your Admin to set target.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  String _formatFull(double amount) {
    return NumberFormat('#,##,###').format(amount);
  }

  Widget _buildOrderPipeline({
    required BuildContext context,
    required bool isDark,
    required OrderPipelineStats stats,
    required bool isDaily,
  }) {
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDaily ? 'TODAY\'S ORDER PIPELINE' : 'MONTHLY ORDER PIPELINE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OrderStatCard(
                label: isDaily ? 'New Today' : 'New This Month',
                value: stats.newOrdersCount.toString(),
                color: const Color(0xFF3B82F6),
                icon: Icons.new_releases_rounded,
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OrderStatCard(
                label: 'Pending',
                value: stats.pendingDispatch.toString(),
                color: const Color(0xFFF59E0B),
                icon: Icons.pending_actions_rounded,
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OrderStatCard(
                label: isDaily ? 'Packed' : 'Packed This Month',
                value: stats.packedCount.toString(),
                color: const Color(0xFF8B5CF6),
                icon: Icons.inventory_2_rounded,
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OrderStatCard(
                label: isDaily ? 'Dispatched' : 'Dispatched This Month',
                value: stats.dispatchedCount.toString(),
                color: const Color(0xFF10B981),
                icon: Icons.local_shipping_rounded,
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : AppColors.primary)
                : AppColors.textTertiary,
          ),
        ),
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

  const _OrderStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: [
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
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
