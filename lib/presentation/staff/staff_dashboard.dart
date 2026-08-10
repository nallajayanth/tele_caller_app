import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/location_permission_helper.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_providers.dart';
import '../../providers/call_log_providers.dart';
import '../common/screens/followup_filter_screen.dart';
import 'tabs/call_form_tab.dart';
import 'tabs/activity_logs_tab.dart';
import 'tabs/performance_tab.dart';
import '../../providers/location_providers.dart';
import '../../providers/attendance_providers.dart';

class StaffDashboard extends ConsumerStatefulWidget {
  const StaffDashboard({super.key});

  @override
  ConsumerState<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends ConsumerState<StaffDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationPermissionHelper.checkAndRequestPermission(context: context);
    });
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
    
    final attendanceAsync = ref.watch(activeAttendanceProvider);
    attendanceAsync.whenData((attendance) {
      if (attendance == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(activeUserProvider.notifier).signOut();
          ref.read(callLogsProvider.notifier).loadLogs();
        });
      }
    });

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
    final activeUser = ref.watch(activeUserProvider);
    final userName = activeUser?.name;

    return Scaffold(
      appBar: AppBar(
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
              userName != null && userName.trim().isNotEmpty
                  ? 'Staff Console • $userName'
                  : 'Staff Console',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (ctx, ref, _) {
              final isShiftActive = ref.watch(shiftStatusProvider);
              return IconButton(
                tooltip: 'Work Shift Location Tracker',
                icon: Icon(
                  isShiftActive ? Icons.location_on_rounded : Icons.location_off_rounded,
                  color: isShiftActive ? AppColors.success : AppColors.textTertiary,
                  size: 22,
                ),
                onPressed: () => _showShiftBottomSheet(context, ref, isShiftActive),
              );
            },
          ),
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 22,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(
              Icons.logout_rounded,
              size: 22,
              color: AppColors.error,
            ),
            onPressed: () => _confirmSignOut(context, ref),
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

  void _showShiftBottomSheet(BuildContext context, WidgetRef ref, bool isActive) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppColors.darkSurface 
          : Colors.white,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final currentActive = ref.watch(shiftStatusProvider);
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Icon(
                    currentActive ? Icons.location_on_rounded : Icons.location_off_rounded,
                    size: 48,
                    color: currentActive ? AppColors.success : AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'WORK SHIFT LOCATION TRACKER',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live GPS coordinates are updated to the Admin Console only during your active work shift.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: currentActive 
                          ? AppColors.success.withValues(alpha: 0.08) 
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentActive 
                            ? AppColors.success.withValues(alpha: 0.3) 
                            : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: currentActive ? AppColors.success : AppColors.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentActive ? 'SHIFT STATUS: ON DUTY' : 'SHIFT STATUS: OFF DUTY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: currentActive ? AppColors.success : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      HapticFeedback.mediumImpact();
                      if (currentActive) {
                        await ref.read(shiftStatusProvider.notifier).endShift();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Shift ended. Location tracking is now OFF.',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: AppColors.textSecondary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        final success = await ref.read(shiftStatusProvider.notifier).startShift();
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Shift started! Background location tracking is active.',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to start shift. Please grant location permissions.',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: Icon(
                      currentActive ? Icons.location_off_rounded : Icons.location_on_rounded,
                      size: 18,
                    ),
                    label: Text(
                      currentActive ? 'End Shift (Clock Out)' : 'Start Shift (Clock In)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentActive ? AppColors.error : AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
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
