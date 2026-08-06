import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/order_providers.dart';
import '../../../core/utils/product_formatter.dart';

class PerformanceTab extends ConsumerWidget {
  const PerformanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetAsync = ref.watch(staffMonthlyTargetProvider);
    final achievement = ref.watch(staffMonthlyAchievementProvider);
    final logsAsync = ref.watch(staffLogsProvider);
    final dailyStats = ref.watch(staffOrderStatsProvider);

    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    return targetAsync.when(
      data: (target) {
        final remaining = (target - achievement) > 0 ? (target - achievement) : 0.0;
        final double percent = target > 0 ? (achievement / target).clamp(0.0, 1.0) : 0.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Month Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthName.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Monthly Sales Performance',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Today's Order Pipeline Stats Dashboard
            _buildDailyOrderStats(context, isDark, dailyStats),

            const SizedBox(height: 16),

            // Performance Ring & Target/Achieved Cards
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, const Color(0xFFF1F5F9)],
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
                  // Circular Ring Visualizer
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
                          color: AppColors.primary,
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
                              color: AppColors.primary,
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

                  // Target vs Achievement Metrics
                  Row(
                    children: [
                      Expanded(
                        child: _MetricItem(
                          title: 'TARGET',
                          value: '₹${_formatAmount(target)}',
                          icon: Icons.flag_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.black12),
                      Expanded(
                        child: _MetricItem(
                          title: 'ACHIEVED',
                          value: '₹${_formatAmount(achievement)}',
                          icon: Icons.stars_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Remaining Target
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: remaining > 0 ? AppColors.accent : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: remaining > 0
                              ? AppColors.accent.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          remaining > 0 ? Icons.trending_up_rounded : Icons.workspace_premium_rounded,
                          color: remaining > 0 ? AppColors.accent : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Operational targets text info
            if (target == 0)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
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
              ),

            // Monthly Order list section
            Text(
              'My Monthly Orders',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            logsAsync.when(
              data: (logs) {
                final monthlyOrders = logs
                    .where((l) =>
                        l.date.year == now.year &&
                        l.date.month == now.month &&
                        l.connectedStatus == 'Order Received')
                    .toList();

                if (monthlyOrders.isEmpty) {
                  return Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text(
                      'No orders logged this month.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthlyOrders.length,
                  itemBuilder: (context, i) {
                    final log = monthlyOrders[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.border,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 18),
                        ),
                        title: Text(
                          log.customerName,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatProduct(log.product)}  •  ${DateFormat('dd MMM').format(log.date)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        trailing: Text(
                          '₹${log.orderValue.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, st) => const SizedBox.shrink(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error loading targets: $e')),
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

  String _formatProduct(String product) {
    return ProductFormatter.format(product);
  }

  Widget _buildDailyOrderStats(BuildContext context, bool isDark, DailyOrderStats stats) {
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MY TODAY\'S ORDER PIPELINE',
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
                label: 'New Today',
                value: stats.newOrdersToday.toString(),
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
                label: 'Packed',
                value: stats.packedToday.toString(),
                color: const Color(0xFF8B5CF6),
                icon: Icons.inventory_2_rounded,
                isDark: isDark,
                cardColor: cardColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OrderStatCard(
                label: 'Dispatched',
                value: stats.dispatchedToday.toString(),
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
