import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

class SuccessToast {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color color = AppColors.success,
    Duration duration = const Duration(seconds: 2),
  }) {
    _entry?.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        icon: icon,
        color: color,
        onDone: () {
          entry.remove();
          _entry = null;
        },
        duration: duration,
      ),
    );
    _entry = entry;
    Overlay.of(context).insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDone;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.onDone,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) setState(() => _visible = false);
      Future.delayed(const Duration(milliseconds: 350), widget.onDone);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: 24,
      right: 24,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              boxShadow: AppShadows.primaryGlow(widget.color),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().slideY(
                begin: 1.0,
                end: 0.0,
                duration: 300.ms,
                curve: Curves.fastOutSlowIn,
              ),
        ),
      ),
    );
  }
}
