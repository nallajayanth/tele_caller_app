import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_providers.dart';
import '../../providers/call_log_providers.dart';
import '../common/screens/followup_filter_screen.dart';
import 'tabs/call_form_tab.dart';
import 'tabs/activity_logs_tab.dart';
import 'tabs/performance_tab.dart';

class StaffDashboard extends ConsumerStatefulWidget {
  const StaffDashboard({super.key});

  @override
  ConsumerState<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends ConsumerState<StaffDashboard> {
  int _currentIndex = 0;

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
    
    // Check Operational Lock: on the 1st of the month, target must be set.
    final targetAsync = ref.watch(staffMonthlyTargetProvider);
    final isFirstOfMonth = DateTime.now().day == 1;

    if (isFirstOfMonth) {
      return targetAsync.when(
        data: (target) {
          if (target <= 0.0) {
            return Scaffold(
              body: Container(
                decoration: const BoxDecoration(gradient: AppColors.roleSelectorGradient),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.error, width: 2),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: AppColors.error,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'CONSOLE LOCKED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The staff console is locked because your monthly target has not been set by the Admin. Under company policy, the console is locked on the 1st of the month until targets are set.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => _confirmSignOut(context, ref),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return _buildScaffold(isDark);
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
        error: (e, _) => _buildScaffold(isDark), // bypass on network or db error to not block work
      );
    }
    
    return _buildScaffold(isDark);
  }

  Widget _buildScaffold(bool isDark) {
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
            Text(
              _currentIndex == 0
                  ? 'New Call Log'
                  : _currentIndex == 1
                      ? 'My Activity'
                      : _currentIndex == 2
                          ? 'Follow-ups'
                          : 'My Performance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Staff Console',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
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
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          CallFormTab(),
          ActivityLogsTab(),
          FollowUpFilterScreen(isAdmin: false),
          PerformanceTab(),
        ],
      ),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomNav({required this.currentIndex, required this.onTap});

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
              _NavItem(
                icon: Icons.add_circle_outline_rounded,
                activeIcon: Icons.add_circle_rounded,
                label: 'New Log',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.timeline_outlined,
                activeIcon: Icons.timeline_rounded,
                label: 'My Logs',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.event_outlined,
                activeIcon: Icons.event_rounded,
                label: 'Follow-ups',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.trending_up_rounded,
                activeIcon: Icons.trending_up_rounded,
                label: 'Performance',
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


class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
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
