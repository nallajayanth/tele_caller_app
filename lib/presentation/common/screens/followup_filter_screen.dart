import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/call_log_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/deleted_log_providers.dart';
import '../../../providers/theme_provider.dart';
import '../../admin/views/admin_edit_modal.dart';
import '../../admin/widgets/admin_log_card.dart';
import '../../common/widgets/success_toast.dart';

class FollowUpFilterScreen extends ConsumerStatefulWidget {
  final bool isAdmin;

  const FollowUpFilterScreen({super.key, this.isAdmin = false});

  @override
  ConsumerState<FollowUpFilterScreen> createState() =>
      _FollowUpFilterScreenState();
}

class _FollowUpFilterScreenState extends ConsumerState<FollowUpFilterScreen> {
  @override
  void initState() {
    super.initState();
    // Reset to today every time screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      ref.read(followUpDateProvider.notifier).state =
          DateTime(now.year, now.month, now.day);
    });
  }

  void _prevDay() {
    HapticFeedback.selectionClick();
    final current = ref.read(followUpDateProvider);
    ref.read(followUpDateProvider.notifier).state =
        current.subtract(const Duration(days: 1));
  }

  void _nextDay() {
    HapticFeedback.selectionClick();
    final current = ref.read(followUpDateProvider);
    ref.read(followUpDateProvider.notifier).state =
        current.add(const Duration(days: 1));
  }

  void _goToToday() {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    ref.read(followUpDateProvider.notifier).state =
        DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final current = ref.read(followUpDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
      ref.read(followUpDateProvider.notifier).state =
          DateTime(picked.year, picked.month, picked.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final selectedDate = ref.watch(followUpDateProvider);
    final logs = ref.watch(followUpLogsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate == today;
    final isYesterday =
        selectedDate == today.subtract(const Duration(days: 1));
    final isTomorrow = selectedDate == today.add(const Duration(days: 1));

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isYesterday) {
      dateLabel = 'Yesterday';
    } else if (isTomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('EEEE').format(selectedDate);
    }

    final totalValue =
        logs.fold<double>(0.0, (s, l) => s + l.orderValue);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Follow-up Tracker',
                style: Theme.of(context).textTheme.titleLarge),
            Text(
              widget.isAdmin ? 'Admin view' : 'Staff view',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500),
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
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Date navigator ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                _NavArrow(
                    icon: Icons.chevron_left_rounded, onTap: _prevDay),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dateLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.textOnDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.calendar_month_rounded,
                                size: 18, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMMM yyyy').format(selectedDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!isToday) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _goToToday,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Jump to Today',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _NavArrow(
                    icon: Icons.chevron_right_rounded, onTap: _nextDay),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 12),

          // ── Summary chips ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _SummaryChip(
                  icon: Icons.list_alt_rounded,
                  label: '${logs.length} Log${logs.length != 1 ? 's' : ''}',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  icon: Icons.currency_rupee_rounded,
                  label: totalValue > 0
                      ? _fmt(totalValue)
                      : 'No orders',
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                if (isToday)
                  _SummaryChip(
                    icon: Icons.notifications_active_rounded,
                    label: 'Due today',
                    color: AppColors.error,
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 12),

          // ── Log list ─────────────────────────────────────────────────
          Expanded(
            child: logs.isEmpty
                ? _EmptyState(
                    date: selectedDate,
                    isToday: isToday,
                    onGoToday: _goToToday,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) {
                      final log = logs[i];
                      if (widget.isAdmin) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AdminSwipeCard(
                            key: ValueKey(log.id),
                            log: log,
                            index: i,
                          ),
                        );
                      }
                      return _ReadOnlyCard(log: log, index: i);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ── Admin swipe card (inline, mirrors admin_terminal logic) ─────────────

class _AdminSwipeCard extends ConsumerWidget {
  final CallLogModel log;
  final int index;

  const _AdminSwipeCard({super.key, required this.log, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('fu_${log.id}'),
      background: _bg(isDelete: false),
      secondaryBackground: _bg(isDelete: true),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          _openEdit(context);
          return false;
        }
        HapticFeedback.mediumImpact();
        return _confirmMoveToBin(context);
      },
      onDismissed: (_) {
        ref.read(deletedLogProvider.notifier).moveToBin(log);
        ref.read(callLogsProvider.notifier).deleteLog(log.id);
        SuccessToast.show(context,
            message: 'Moved to Recycle Bin.',
            icon: Icons.delete_sweep_rounded,
            color: AppColors.error);
      },
      child: AdminLogCard(
        log: log,
        index: index,
        onEdit: () => _openEdit(context),
        onDelete: () => _handleDeleteTap(context, ref),
      ),
    );
  }

  Widget _bg({required bool isDelete}) => Container(
        decoration: BoxDecoration(
          color: isDelete ? AppColors.error : AppColors.primary,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        alignment:
            isDelete ? Alignment.centerRight : Alignment.centerLeft,
        padding: EdgeInsets.only(
            left: isDelete ? 0 : 24, right: isDelete ? 24 : 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: isDelete
              ? [
                  Text('Move to Bin',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(width: 8),
                  const Icon(Icons.delete_sweep_rounded,
                      color: Colors.white, size: 22),
                ]
              : [
                  const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text('Edit',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
        ),
      );

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
        title: Text('Move to Bin?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        content: Text(
          'The log for "${log.customerName}" will be moved to the Recycle Bin and permanently deleted after 30 days.',
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

  Future<void> _handleDeleteTap(BuildContext context, WidgetRef ref) async {
    final confirm = await _confirmMoveToBin(context);
    if (confirm && context.mounted) {
      ref.read(deletedLogProvider.notifier).moveToBin(log);
      ref.read(callLogsProvider.notifier).deleteLog(log.id);
      SuccessToast.show(context,
          message: 'Moved to Recycle Bin.',
          icon: Icons.delete_sweep_rounded,
          color: AppColors.error);
    }
  }
}

// ── Read-only card for staff ─────────────────────────────────────────────

class _ReadOnlyCard extends StatefulWidget {
  final CallLogModel log;
  final int index;

  const _ReadOnlyCard({required this.log, required this.index});

  @override
  State<_ReadOnlyCard> createState() => _ReadOnlyCardState();
}

class _ReadOnlyCardState extends State<_ReadOnlyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final log = widget.log;
    final statusColor = AppColors.statusColor(log.connectedStatus);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_statusIcon(log.connectedStatus),
                        color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.customerName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textOnDark
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                log.place,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        _CopyablePhone(mobile: log.mobile),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (log.orderValue > 0)
                        Text(
                          '₹${_fmt(log.orderValue)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent),
                        ),
                      const SizedBox(height: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textTertiary, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  _StatusPill(label: log.connectedStatus, color: statusColor),
                  const SizedBox(width: 6),
                  if (log.product.isNotEmpty)
                    Expanded(
                      child: _StatusPill(
                          label: '💊 ${log.product}',
                          color: AppColors.info),
                    ),
                  const Spacer(),
                  Text(
                    DateFormat('hh:mm a').format(log.date),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              child: _expanded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.border,
                              height: 16),
                          if (log.customerResponse.isNotEmpty) ...[
                            _DetailRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Response',
                                value: log.customerResponse),
                            const SizedBox(height: 8),
                          ],
                          if (log.remarks.isNotEmpty)
                            _DetailRow(
                                icon: Icons.edit_note_rounded,
                                label: 'Remarks',
                                value: log.remarks),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: 50 * widget.index))
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.08),
    );
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'connected':   return Icons.check_circle_rounded;
      case 'busy':        return Icons.phone_in_talk_rounded;
      case 'no answer':   return Icons.phone_missed_rounded;
      case 'call back':   return Icons.phone_callback_rounded;
      case 'not interested': return Icons.thumb_down_rounded;
      case 'interested':  return Icons.thumb_up_rounded;
      default:            return Icons.phone_rounded;
    }
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textOnDark
                          : AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final VoidCallback onGoToday;

  const _EmptyState(
      {required this.date, required this.isToday, required this.onGoToday});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.event_available_rounded,
                  color: AppColors.primary, size: 36),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              'No follow-ups scheduled',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 8),
            Text(
              isToday
                  ? 'No calls are due for follow-up today.'
                  : 'No calls are scheduled for ${DateFormat('dd MMM yyyy').format(date)}.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textTertiary, height: 1.5),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 220.ms),
            if (!isToday) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onGoToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Go to Today',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],
          ],
        ),
      ),
    );
  }
}
