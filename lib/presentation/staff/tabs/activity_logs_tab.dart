import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/call_log_providers.dart';
import '../widgets/activity_log_card.dart';

class ActivityLogsTab extends ConsumerWidget {
  const ActivityLogsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(staffLogsProvider);

    return logsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        if (logs.isEmpty) {
          return _EmptyState();
        }

        // Group logs by date
        final grouped = <String, List<dynamic>>{};
        for (final log in logs) {
          final key = DateFormat('yyyy-MM-dd').format(log.date);
          grouped.putIfAbsent(key, () => []).add(log);
        }
        final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.textTertiary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isToday
                              ? 'Today'
                              : DateFormat('dd MMM, EEEE').format(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isToday ? AppColors.primary : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Divider(
                          color: AppColors.border.withValues(alpha: 0.6),
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
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'No activity yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Your call logs will appear here\nonce you start logging.',
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
