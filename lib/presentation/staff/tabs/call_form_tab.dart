import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/call_log_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../common/widgets/premium_button.dart';
import '../../common/widgets/status_chip_selector.dart';
import '../../common/widgets/success_toast.dart';

const _uuid = Uuid();

class CallFormTab extends ConsumerStatefulWidget {
  const CallFormTab({super.key});

  @override
  ConsumerState<CallFormTab> createState() => _CallFormTabState();
}

class _CallFormTabState extends ConsumerState<CallFormTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _responseCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();

  String? _selectedStatus;
  DateTime _followUpDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  bool _statusError = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _placeCtrl.dispose();
    _productCtrl.dispose();
    _responseCtrl.dispose();
    _remarksCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked != null) setState(() => _followUpDate = picked);
  }

  Future<void> _submit() async {
    final isFormValid = _formKey.currentState!.validate();
    if (_selectedStatus == null) {
      setState(() => _statusError = true);
    }
    if (!isFormValid || _selectedStatus == null) return;

    setState(() => _isSubmitting = true);

    final log = CallLogModel(
      id: _uuid.v4(),
      date: DateTime.now(),
      customerName: _nameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      place: _placeCtrl.text.trim(),
      product: _productCtrl.text.trim(),
      connectedStatus: _selectedStatus!,
      customerResponse: _responseCtrl.text.trim(),
      nextFollowUpDate: _followUpDate,
      orderValue: double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0,
      remarks: _remarksCtrl.text.trim(),
      deviceId: deviceId,
    );

    final success = await ref.read(callLogsProvider.notifier).addLog(log);

    setState(() => _isSubmitting = false);

    if (success) {
      _clearForm();
      if (mounted) {
        SuccessToast.show(context, message: 'Call log saved successfully!');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send data to Supabase. Check your RLS policies or database connections.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _mobileCtrl.clear();
    _placeCtrl.clear();
    _productCtrl.clear();
    _responseCtrl.clear();
    _remarksCtrl.clear();
    _orderCtrl.clear();
    setState(() {
      _selectedStatus = null;
      _statusError = false;
      _followUpDate = DateTime.now().add(const Duration(days: 1));
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _DateChip().animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),

          _SectionCard(
            color: cardColor,
            title: 'Customer Info',
            icon: Icons.person_rounded,
            children: [
              _Field(
                controller: _nameCtrl,
                label: 'Customer Name *',
                hint: 'Doctor / Retail Pharmacy',
                icon: Icons.store_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _mobileCtrl,
                label: 'Mobile Number *',
                hint: '10-digit mobile',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length != 10) return 'Enter valid 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _placeCtrl,
                label: 'Place / Market Area (Optional)',
                hint: 'City or region',
                icon: Icons.location_on_rounded,
                validator: null,
              ),
            ],
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),

          const SizedBox(height: 14),

          _SectionCard(
            color: cardColor,
            title: 'Product',
            icon: Icons.medication_rounded,
            children: [
              _Field(
                controller: _productCtrl,
                label: 'Product / Remedy *',
                hint: 'e.g. Arnica 30, Rhus Tox 200',
                icon: Icons.science_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),

          const SizedBox(height: 14),

          _SectionCard(
            color: cardColor,
            title: 'Call Status *',
            icon: Icons.signal_cellular_alt_rounded,
            children: [
              StatusChipSelector(
                selected: _selectedStatus,
                onChanged: (s) => setState(() {
                  _selectedStatus = s;
                  _statusError = false;
                }),
              ),
              if (_statusError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Please select a call status',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.1),

          const SizedBox(height: 14),

          _SectionCard(
            color: cardColor,
            title: 'Notes',
            icon: Icons.notes_rounded,
            children: [
              _Field(
                controller: _responseCtrl,
                label: 'Customer Response (Optional)',
                hint: 'Detailed feedback from customer...',
                icon: Icons.chat_bubble_outline_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _remarksCtrl,
                label: 'Remarks (Optional)',
                hint: 'Internal notes, follow-up context...',
                icon: Icons.edit_note_rounded,
                maxLines: 2,
              ),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

          const SizedBox(height: 14),

          _SectionCard(
            color: cardColor,
            title: 'Follow-Up Date *',
            icon: Icons.calendar_today_rounded,
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, dd MMM yyyy').format(_followUpDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.1),

          const SizedBox(height: 14),

          _SectionCard(
            color: cardColor,
            title: 'Order Value *',
            icon: Icons.currency_rupee_rounded,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _orderCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.replaceAll(',', '')) == null) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Container(
                          padding: const EdgeInsets.only(left: 14, right: 8),
                          child: Text(
                            '₹',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '0.00',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppColors.textTertiary,
                          fontSize: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: BorderSide(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        ),
                        fillColor: AppColors.accent.withValues(alpha: 0.04),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _orderCtrl.text = '0');
                    },
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.exposure_zero_rounded,
                            color: AppColors.textTertiary, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),

          const SizedBox(height: 24),

          PremiumButton(
            label: 'Save Call Log',
            isLoading: _isSubmitting,
            onTap: _isSubmitting ? null : _submit,
            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
          ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF005F54), Color(0xFF00857A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: AppShadows.primaryGlow(AppColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.today_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'Today: ${DateFormat('EEEE, dd MMM yyyy').format(DateTime.now())}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'LOCKED',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color color;
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.color,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: AppSpacing.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
      ),
    );
  }
}
