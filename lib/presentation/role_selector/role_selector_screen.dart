import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../providers/call_log_providers.dart';
import '../admin/admin_terminal.dart';
import '../staff/staff_dashboard.dart';
import '../warehouse/warehouse_dashboard.dart';

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.roleSelectorGradient),
        child: Stack(
          children: [
            // Decorative ambient circles
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.06),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 56),
                    _buildBranding().animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
                    const Spacer(),
                    Text(
                      'SELECT YOUR ACCESS MODE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 2.5,
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        _RoleCard(
                          title: 'Staff Console',
                          subtitle: 'Log your daily call activity',
                          icon: Icons.headset_mic_rounded,
                          gradientColors: [
                            const Color(0xFF00857A),
                            const Color(0xFF005F54),
                          ],
                          delay: 450,
                          onTap: () => _navigate(context, const StaffDashboard()),
                        ),
                        const SizedBox(height: 12),
                        _RoleCard(
                          title: 'Warehouse Console',
                          subtitle: 'Fulfil & dispatch orders',
                          icon: Icons.inventory_rounded,
                          gradientColors: [
                            const Color(0xFF3B82F6),
                            const Color(0xFF1E3A8A),
                          ],
                          delay: 500,
                          onTap: () => _navigate(context, const WarehouseDashboard()),
                        ),
                        const SizedBox(height: 12),
                        _RoleCard(
                          title: 'Admin Terminal',
                          subtitle: 'Full business control center',
                          icon: Icons.shield_rounded,
                          gradientColors: [
                            const Color(0xFFD97706),
                            const Color(0xFFB45309),
                          ],
                          delay: 550,
                          onTap: () => _showPinDialog(context),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                    const Spacer(),
                    Text(
                      'HT TELECALING  •  v1.0.0',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.25),
                        letterSpacing: 1.2,
                      ),
                    ).animate().fadeIn(delay: 700.ms),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset(
              'assets/logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'HT TELECALING',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Homeopathy Medicine Distribution Suite',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showPinDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (_, _, _) => _PinDialog(
        onSuccess: () {
          Navigator.of(context).pop();
          _navigate(context, const AdminTerminal());
        },
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.fastOutSlowIn),
          ),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: anim, curve: Curves.fastOutSlowIn),
          ),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 380),
    ));
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final int delay;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140), value: 1);
    _scale = Tween(begin: 0.94, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _ctrl.reverse();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -25,
                    right: -25,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: widget.gradientColors),
                      ),
                    ).animate(delay: Duration(milliseconds: widget.delay))
                        .fadeIn(duration: 600.ms),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: widget.gradientColors),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(widget.icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 28),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const _PinDialog({required this.onSuccess});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog>
    with SingleTickerProviderStateMixin {
  final List<String> _pin = [];
  bool _hasError = false;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin.add(digit);
      _hasError = false;
    });
    if (_pin.length == 4) _checkPin();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _pin.removeLast());
  }

  void _checkPin() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_pin.join() == adminPin) {
      HapticFeedback.heavyImpact();
      widget.onSuccess();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _hasError = true;
        _pin.clear();
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFB45309)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Admin Access',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hasError ? 'Incorrect PIN. Try again.' : 'Enter your 4-digit PIN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _hasError
                              ? AppColors.error
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: child,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (i) {
                            final filled = i < _pin.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hasError
                                    ? AppColors.error
                                    : filled
                                        ? AppColors.accent
                                        : Colors.white.withValues(alpha: 0.2),
                                boxShadow: filled && !_hasError
                                    ? [
                                        BoxShadow(
                                          color: AppColors.accent.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Numpad
                      ...['1 2 3', '4 5 6', '7 8 9'].map((row) {
                        final digits = row.split(' ');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: digits.map((d) => _PinKey(digit: d, onTap: _onKey)).toList(),
                          ),
                        );
                      }),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 72),
                          _PinKey(digit: '0', onTap: _onKey),
                          _BackspaceKey(onTap: _onBackspace),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  final String digit;
  final void Function(String) onTap;

  const _PinKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(digit),
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Text(
            digit,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final VoidCallback onTap;

  const _BackspaceKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}
