import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/deleted_log_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/deleted_log_providers.dart';
import '../../common/widgets/success_toast.dart';

class BinScreen extends ConsumerWidget {
  const BinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(deletedLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recycle Bin', style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Logs auto-delete after 30 days',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (entries.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmEmptyBin(context, ref, entries.length),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(
                'Empty',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: entries.isEmpty
          ? const _EmptyBin()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _BinCard(
                key: ValueKey(entries[i].id),
                entry: entries[i],
                index: i,
              ),
            ),
    );
  }

  Future<void> _confirmEmptyBin(
      BuildContext context, WidgetRef ref, int count) async {
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
          child: const Icon(Icons.delete_forever_rounded,
              color: AppColors.error, size: 28),
        ),
        title: Text(
          'Empty Recycle Bin?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '$count log${count > 1 ? 's' : ''} will be permanently deleted. This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: Text('Delete All',
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
    if (confirm == true && context.mounted) {
      await ref.read(deletedLogProvider.notifier).emptyBin();
      if (context.mounted) {
        SuccessToast.show(context,
            message: 'Recycle Bin emptied.',
            icon: Icons.delete_sweep_rounded,
            color: AppColors.error);
      }
    }
  }
}

class _BinCard extends ConsumerWidget {
  final DeletedLogModel entry;
  final int index;

  const _BinCard({super.key, required this.entry, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = AppColors.statusColor(entry.connectedStatus);
    final daysAgo = DateTime.now().difference(entry.deletedAt).inDays;
    final daysLeft = 30 - daysAgo;
    final isExpiringSoon = daysLeft <= 3;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isExpiringSoon
              ? AppColors.error.withValues(alpha: 0.45)
              : (isDark ? AppColors.borderDark : AppColors.border),
          width: isExpiringSoon ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon(entry.connectedStatus),
                      color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.customerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              entry.place,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _CopyablePhone(mobile: entry.mobile),
                    ],
                  ),
                ),
                if (entry.orderValue > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹${_fmt(entry.orderValue)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Status pill + deletion info
            Row(
              children: [
                _Pill(label: entry.connectedStatus, color: statusColor),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: isExpiringSoon
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.textTertiary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpiringSoon
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                        size: 11,
                        color: isExpiringSoon
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        daysAgo == 0
                            ? 'Deleted today'
                            : 'Deleted $daysAgo day${daysAgo > 1 ? 's' : ''} ago',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isExpiringSoon
                              ? AppColors.error
                              : AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        ' · $daysLeft day${daysLeft != 1 ? 's' : ''} left',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isExpiringSoon
                              ? AppColors.error
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Original log: ${DateFormat('dd MMM yyyy, hh:mm a').format(entry.date)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            Divider(
              color: isDark ? AppColors.borderDark : AppColors.border,
              height: 1,
            ),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _restore(context, ref),
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: Text(
                      'Restore',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _permanentDelete(context, ref),
                    icon: const Icon(Icons.delete_forever_rounded, size: 16),
                    label: Text(
                      'Delete Forever',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 50 * (index % 10)))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final log = await ref.read(deletedLogProvider.notifier).restore(entry.id);
    if (log != null) {
      await ref.read(callLogsProvider.notifier).addLog(log);
    }
    if (context.mounted) {
      SuccessToast.show(
        context,
        message: '${entry.customerName} restored!',
        icon: Icons.restore_rounded,
        color: AppColors.primary,
      );
    }
  }

  Future<void> _permanentDelete(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
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
          child: const Icon(Icons.delete_forever_rounded,
              color: AppColors.error, size: 28),
        ),
        title: Text(
          'Delete Forever?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '"${entry.customerName}" will be permanently deleted and cannot be restored.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: Text('Delete Forever',
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
    if (confirm == true && context.mounted) {
      await ref.read(deletedLogProvider.notifier).permanentDelete(entry.id);
      if (context.mounted) {
        SuccessToast.show(
          context,
          message: 'Permanently deleted.',
          icon: Icons.delete_forever_rounded,
          color: AppColors.error,
        );
      }
    }
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return Icons.check_circle_rounded;
      case 'busy':
        return Icons.phone_in_talk_rounded;
      case 'no answer':
        return Icons.phone_missed_rounded;
      case 'call back':
        return Icons.phone_callback_rounded;
      case 'not interested':
        return Icons.thumb_down_rounded;
      case 'interested':
        return Icons.thumb_up_rounded;
      default:
        return Icons.phone_rounded;
    }
  }
}

class _CopyablePhone extends StatelessWidget {
  final String mobile;
  const _CopyablePhone({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: mobile));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$mobile copied',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_rounded, size: 12, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(mobile,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.copy_rounded, size: 10, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
          overflow: TextOverflow.ellipsis),
    );
  }
}

class _EmptyBin extends StatelessWidget {
  const _EmptyBin();

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
              color: AppColors.textTertiary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                size: 40, color: AppColors.textTertiary),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'Recycle Bin is Empty',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          Text(
            'Deleted logs will appear here for 30 days\nbefore being permanently removed.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 220.ms),
        ],
      ),
    );
  }
}
