import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

class StatusOption {
  final String label;
  final IconData icon;
  final Color color;

  const StatusOption({
    required this.label,
    required this.icon,
    required this.color,
  });
}

const kStatusOptions = [
  StatusOption(label: 'Connected', icon: Icons.check_circle_rounded, color: AppColors.connected),
  StatusOption(label: 'Order Received', icon: Icons.shopping_bag_rounded, color: Color(0xFF0D9488)),
  StatusOption(label: 'Busy', icon: Icons.phone_in_talk_rounded, color: AppColors.busy),
  StatusOption(label: 'No Answer', icon: Icons.phone_missed_rounded, color: AppColors.noAnswer),
  StatusOption(label: 'Call Back', icon: Icons.phone_callback_rounded, color: AppColors.callBack),
  StatusOption(label: 'Not Interested', icon: Icons.thumb_down_rounded, color: AppColors.notInterested),
  StatusOption(label: 'Interested', icon: Icons.thumb_up_rounded, color: AppColors.interested),
];

class StatusChipSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const StatusChipSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: kStatusOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = kStatusOptions[i];
          final isSelected = selected == opt.label;
          return _StatusChip(
            option: opt,
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(opt.label);
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatefulWidget {
  final StatusOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150), value: 1);
    _scale = Tween(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.option.color;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.35),
              width: isSelected ? 0 : 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.option.icon,
                size: 15,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.option.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
