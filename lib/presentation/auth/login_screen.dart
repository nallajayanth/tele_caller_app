import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/call_log_providers.dart';
import '../common/widgets/premium_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _obscurePin = true;
  bool _isLoading = false;
  String _loadingMsg = '';
  int _shakeTrigger = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _triggerError() {
    HapticFeedback.vibrate();
    if (mounted) {
      setState(() {
        _shakeTrigger++;
        _isLoading = false;
        _loadingMsg = '';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _triggerError();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingMsg = 'Authenticating...';
      });
    }
    HapticFeedback.lightImpact();

    final phone = _phoneCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    try {
      // Step 1: Validate credentials first without switching screen state
      final user = await ref.read(activeUserProvider.notifier).validateCredentials(phone, pin);
      if (user == null) {
        _triggerError();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid credentials. Access denied.',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Step 2: Populate Call Logs
      await ref.read(callLogsProvider.notifier).loadLogs();

      // Step 3: Now set user session (navigates to dashboard)
      await ref.read(activeUserProvider.notifier).setUserSession(user);

      HapticFeedback.heavyImpact();
    } catch (e) {
      _triggerError();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception:', '').trim(),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMsg = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.roleSelectorGradient),
        child: Stack(
          children: [
            // Decorative ambient glowing circles
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader().animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
                      const SizedBox(height: 36),
                      Animate(
                        key: ValueKey(_shakeTrigger),
                        effects: [
                          if (_shakeTrigger > 0)
                            const ShakeEffect(
                              hz: 8,
                              curve: Curves.easeInOut,
                              duration: Duration(milliseconds: 400),
                            ),
                        ],
                        child: _buildLoginForm(),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 48),
                      Text(
                        'HT TELECALING  •  v1.0.0',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.25),
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(delay: 600.ms),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/logo.jpg', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'HT TELECALING',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
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
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHONE NUMBER',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter 10-digit number',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Colors.white54, size: 20),
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.error, width: 1.2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length != 10) return 'Invalid 10-digit number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'ACCESS PIN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, letterSpacing: _obscurePin ? 8.0 : 1.5),
                  decoration: InputDecoration(
                    hintText: 'Enter access PIN',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.error, width: 1.2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length != 4 && v.trim().length != 6) {
                      return 'Invalid PIN length (4 or 6 digits)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PremiumButton(
                  label: _isLoading && _loadingMsg.isNotEmpty ? _loadingMsg : 'Sign In',
                  isLoading: _isLoading,
                  onTap: _isLoading ? null : _submit,
                  icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
