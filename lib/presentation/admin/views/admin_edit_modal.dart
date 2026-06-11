import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/call_log_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../common/widgets/premium_button.dart';
import '../../common/widgets/status_chip_selector.dart';
import '../../common/widgets/success_toast.dart';

class AdminEditModal extends ConsumerStatefulWidget {
  final CallLogModel log;

  const AdminEditModal({super.key, required this.log});

  @override
  ConsumerState<AdminEditModal> createState() => _AdminEditModalState();
}

class _AdminEditModalState extends ConsumerState<AdminEditModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _placeCtrl;
  late final TextEditingController _productCtrl;
  late final TextEditingController _responseCtrl;
  late final TextEditingController _remarksCtrl;
  late final TextEditingController _orderCtrl;

  late String? _selectedStatus;
  late DateTime _followUpDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _nameCtrl = TextEditingController(text: log.customerName);
    _mobileCtrl = TextEditingController(text: log.mobile);
    _placeCtrl = TextEditingController(text: log.place);
    _productCtrl = TextEditingController(text: log.product);
    _responseCtrl = TextEditingController(text: log.customerResponse);
    _remarksCtrl = TextEditingController(text: log.remarks);
    _orderCtrl =
        TextEditingController(text: log.orderValue.toStringAsFixed(0));
    _selectedStatus =
        log.connectedStatus.isEmpty ? null : log.connectedStatus;
    _followUpDate = log.nextFollowUpDate;
  }

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
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updated = widget.log.copyWith(
      customerName: _nameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      place: _placeCtrl.text.trim(),
      product: _productCtrl.text.trim(),
      connectedStatus: _selectedStatus ?? widget.log.connectedStatus,
      customerResponse: _responseCtrl.text.trim(),
      nextFollowUpDate: _followUpDate,
      orderValue:
          double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0,
      remarks: _remarksCtrl.text.trim(),
    );

    final success = await ref.read(callLogsProvider.notifier).updateLog(updated);

    setState(() => _isSaving = false);

    if (success) {
      if (mounted) {
        Navigator.of(context).pop();
        SuccessToast.show(context, message: 'Log updated successfully!');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update log in database. Check RLS or connection.',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Log',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textOnDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.log.customerName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _EditField(ctrl: _nameCtrl, label: 'Customer Name', icon: Icons.store_rounded,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    _EditField(
                      ctrl: _mobileCtrl,
                      label: 'Mobile Number',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _EditField(ctrl: _placeCtrl, label: 'Place', icon: Icons.location_on_rounded),
                    const SizedBox(height: 12),
                    _EditField(ctrl: _productCtrl, label: 'Product / Remedy', icon: Icons.medication_rounded),
                    const SizedBox(height: 16),
                    Text(
                      'CALL STATUS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatusChipSelector(
                      selected: _selectedStatus,
                      onChanged: (s) => setState(() => _selectedStatus = s),
                    ),
                    const SizedBox(height: 16),
                    _EditField(
                      ctrl: _responseCtrl,
                      label: 'Customer Response',
                      icon: Icons.chat_bubble_outline_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _EditField(
                      ctrl: _remarksCtrl,
                      label: 'Remarks',
                      icon: Icons.edit_note_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    // Follow-up date
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Follow-up: ${DateFormat('dd MMM yyyy').format(_followUpDate)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Order value
                    TextFormField(
                      controller: _orderCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Order Value (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded,
                            color: AppColors.accent, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: const BorderSide(
                              color: AppColors.accent, width: 2),
                        ),
                        fillColor: AppColors.accent.withValues(alpha: 0.04),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    PremiumButton(
                      label: 'Confirm Modifications',
                      isLoading: _isSaving,
                      onTap: _isSaving ? null : _save,
                      icon: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
      ),
    );
  }
}
