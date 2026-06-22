import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/call_log_providers.dart';
import 'target_management_screen.dart';
import 'user_management_screen.dart';

class EmployeeMonitoringScreen extends ConsumerWidget {
  const EmployeeMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    final employeesAsync = ref.watch(employeesProvider);
    final targetsAsync = ref.watch(adminTargetProvider);
    final logsAsync = ref.watch(callLogsProvider);

    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Monitoring', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(employeesProvider);
          ref.invalidate(adminTargetProvider);
          await ref.read(callLogsProvider.notifier).loadLogs();
        },
        child: employeesAsync.when(
          data: (employees) {
            final staffMembers = employees.where((e) => e.role == 'staff').toList();
  
            if (staffMembers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: Center(
                      child: Text(
                        'No staff members registered.',
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ],
              );
            }
  
            return targetsAsync.when(
              data: (targetsMap) {
                return logsAsync.when(
                  data: (logs) {
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: staffMembers.length,
                    itemBuilder: (context, i) {
                      final staff = staffMembers[i];
                      final deviceId = '00000000-0000-0000-0000-${staff.phoneNumber.padLeft(12, '0')}';
                      
                      final target = targetsMap[deviceId] ?? 0.0;

                      // Filter logs for this employee for the current month
                      final employeeLogs = logs.where((l) =>
                          l.deviceId == deviceId &&
                          l.date.year == now.year &&
                          l.date.month == now.month).toList();

                      // Aggregates
                      final achieved = employeeLogs
                          .where((l) => l.connectedStatus == 'Order Received')
                          .fold<double>(0.0, (sum, l) => sum + l.orderValue);

                      final collected = employeeLogs
                          .where((l) => l.connectedStatus == 'Order Received')
                          .fold<double>(0.0, (sum, l) => sum + l.amountReceived);

                      final due = employeeLogs
                          .where((l) => l.connectedStatus == 'Order Received')
                          .fold<double>(0.0, (sum, l) => sum + l.amountDue);

                      final double progressPercent = target > 0 ? (achieved / target).clamp(0.0, 1.0) : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Staff Header
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staff.name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        staff.phoneNumber,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Progress bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'MONTHLY TARGET PROGRESS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTertiary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '${(progressPercent * 100).toStringAsFixed(0)}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progressPercent,
                                  minHeight: 8,
                                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Financial metrics grid
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatBox(
                                      label: 'TARGET',
                                      value: '₹${_formatCurrency(target)}',
                                      color: AppColors.textPrimary,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatBox(
                                      label: 'ACHIEVED',
                                      value: '₹${_formatCurrency(achieved)}',
                                      color: AppColors.primary,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatBox(
                                      label: 'COLLECTED',
                                      value: '₹${_formatCurrency(collected)}',
                                      color: AppColors.success,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatBox(
                                      label: 'OUTSTANDING',
                                      value: '₹${_formatCurrency(due)}',
                                      color: AppColors.accent,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading call logs: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading targets: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading employees: $e')),
      ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##,###').format(amount);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color == AppColors.textPrimary
        ? (isDark ? Colors.white70 : AppColors.textPrimary)
        : color;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
