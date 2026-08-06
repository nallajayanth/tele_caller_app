import 'dart:convert';
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
import '../../../data/models/product_model.dart';
import '../../../providers/product_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/call_log_providers.dart';
import '../../common/widgets/premium_button.dart';
import '../../common/widgets/status_chip_selector.dart';
import '../../common/widgets/success_toast.dart';
import '../widgets/attendance_card.dart';

const _uuid = Uuid();

class CallFormTab extends ConsumerStatefulWidget {
  const CallFormTab({super.key});

  @override
  ConsumerState<CallFormTab> createState() => _CallFormTabState();
}

class _CallFormTabState extends ConsumerState<CallFormTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _responseCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');
  final _amountReceivedCtrl = TextEditingController(text: '0');
  final _amountDueCtrl = TextEditingController(text: '0');

  String? _selectedStatus;
  DateTime _followUpDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  bool _statusError = false;
  bool _whatsappDone = false;
  String? _selectedStandardRemark;
  bool _showCustomRemarksField = false;

  Map<String, _ProductSelection> _selectedProducts = {};

  @override
  void initState() {
    super.initState();
    _orderCtrl.addListener(_updateAmountDue);
    _amountReceivedCtrl.addListener(_updateAmountDue);
  }

  void _updateAmountDue() {
    final orderVal = double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0;
    final amtReceived = double.tryParse(_amountReceivedCtrl.text.replaceAll(',', '')) ?? 0.0;
    final amtDue = orderVal - amtReceived;
    final newText = amtDue >= 0 ? amtDue.toStringAsFixed(2) : '0.00';
    if (_amountDueCtrl.text != newText) {
      _amountDueCtrl.text = newText;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clinicCtrl.dispose();
    _mobileCtrl.dispose();
    _placeCtrl.dispose();
    _responseCtrl.dispose();
    _remarksCtrl.dispose();
    _orderCtrl.dispose();
    _amountReceivedCtrl.dispose();
    _amountDueCtrl.dispose();
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

  bool get isFormValid => _formKey.currentState?.validate() ?? false;

  Future<void> _submit() async {
    if (!isFormValid || _selectedStatus == null) return;

    setState(() => _isSubmitting = true);

    final String productStr = _selectedProducts.isEmpty
        ? ''
        : jsonEncode(
            _selectedProducts.entries
                .map((e) => {'name': e.key, 'qty': e.value.qty, 'price': e.value.price})
                .toList(),
          );

    final log = CallLogModel(
      id: _uuid.v4(),
      date: DateTime.now(),
      customerName: _nameCtrl.text.trim(),
      clinicName: _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      place: _placeCtrl.text.trim(),
      product: productStr,
      connectedStatus: _selectedStatus!,
      customerResponse: _responseCtrl.text.trim(),
      nextFollowUpDate: _followUpDate,
      orderValue: double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0,
      remarks: _showCustomRemarksField ? _remarksCtrl.text.trim() : '',
      deviceId: ref.read(deviceIdProvider),
      amountReceived: double.tryParse(_amountReceivedCtrl.text.replaceAll(',', '')) ?? 0.0,
      amountDue: double.tryParse(_amountDueCtrl.text.replaceAll(',', '')) ?? 0.0,
      whatsappDone: _whatsappDone,
      standardRemark: _selectedStandardRemark,
      orderStatus: _selectedStatus == 'Order Received' ? 'received' : null,
      orderStatusUpdatedAt: _selectedStatus == 'Order Received' ? DateTime.now() : null,
    );

    final success = await ref.read(callLogsProvider.notifier).addLog(log);
    setState(() => _isSubmitting = false);

    if (success) {
      _clearForm();
      if (mounted) SuccessToast.show(context, message: 'Call log saved successfully!');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save log. Please try again.',
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
    _clinicCtrl.clear();
    _mobileCtrl.clear();
    _placeCtrl.clear();
    _responseCtrl.clear();
    _remarksCtrl.clear();
    _orderCtrl.text = '0';
    _amountReceivedCtrl.text = '0';
    _amountDueCtrl.text = '0';
    setState(() {
      _selectedStatus = null;
      _statusError = false;
      _followUpDate = DateTime.now().add(const Duration(days: 1));
      _isSubmitting = false;
      _whatsappDone = false;
      _selectedStandardRemark = null;
      _showCustomRemarksField = false;
      _selectedProducts = {};
    });
  }

  void _showProductPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPickerSheet(
        initialSelections: Map.from(_selectedProducts),
        onConfirm: (selections) {
          final total = selections.entries.fold<double>(
            0, (sum, e) => sum + e.value.qty * e.value.price,
          );
          setState(() {
            _selectedProducts = selections;
            _orderCtrl.text = total.toStringAsFixed(0);
          });
        },
      ),
    );
  }

  Widget _buildProductSelector(BuildContext context, bool isDark, Color cardColor) {
    final bool hasSelection = _selectedProducts.isNotEmpty;
    final double total = _selectedProducts.entries
        .fold(0, (sum, e) => sum + e.value.qty * e.value.price);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Picker trigger button
        GestureDetector(
          onTap: _showProductPicker,
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
                const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasSelection
                        ? '${_selectedProducts.length} product(s) selected'
                        : 'Search & select products...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: hasSelection
                          ? (isDark ? AppColors.textOnDark : AppColors.textPrimary)
                          : AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  hasSelection ? Icons.edit_rounded : Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        // Selected products summary with qty, price, subtotal
        if (hasSelection) ...[
          const SizedBox(height: 10),
          ..._selectedProducts.entries.map((entry) {
            final subtotal = entry.value.qty * entry.value.price;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value.qty} × ₹${entry.value.price.toStringAsFixed(0)} = ₹${subtotal.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ₹${total.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
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
          const SizedBox(height: 12),
          const AttendanceCard(),
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _clinicCtrl,
                label: 'Clinic Name (Optional)',
                hint: 'Clinic / Hospital name',
                icon: Icons.local_hospital_rounded,
                validator: null,
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
            title: 'Product (Optional)',
            icon: Icons.medication_rounded,
            children: [
              _buildProductSelector(context, isDark, cardColor),
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
                  _updateAmountDue();
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
            title: 'Notes & Remarks',
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
              DropdownButtonFormField<String>(
                initialValue: _selectedStandardRemark,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Standard Remark (Optional)',
                  prefixIcon: Icon(Icons.feedback_rounded,
                      color: AppColors.textTertiary, size: 20),
                ),
                dropdownColor: cardColor,
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
                items: [
                  'Prices are High',
                  'Quality is Not Good',
                  'Service is Not Good',
                  'Logistics Charges are High',
                  'Other',
                ].map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedStandardRemark = val;
                    if (val == 'Other') {
                      _showCustomRemarksField = true;
                    } else {
                      _showCustomRemarksField = false;
                      _remarksCtrl.clear();
                    }
                  });
                },
              ),
              if (_showCustomRemarksField) ...[
                const SizedBox(height: 14),
                _Field(
                  controller: _remarksCtrl,
                  label: 'Custom Remarks *',
                  hint: 'Enter your custom notes here...',
                  icon: Icons.edit_note_rounded,
                  maxLines: 2,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required for Other' : null,
                ),
              ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      const Icon(Icons.event_rounded,
                          color: AppColors.primary, size: 20),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (v) {
                        if (_selectedStatus == 'Order Received') {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required for Order Received';
                          }
                          final val = double.tryParse(v.replaceAll(',', ''));
                          if (val == null || val <= 0) {
                            return 'Must be greater than 0';
                          }
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
                          padding:
                              const EdgeInsets.only(left: 14, right: 8),
                          child: Text(
                            '₹',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '0.00',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppColors.textTertiary,
                          fontSize: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: BorderSide(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
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
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _orderCtrl.text = '0');
                    },
                    child: Container(
                      height: 56,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                        border: Border.all(
                            color: AppColors.border, width: 1.5),
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

          const SizedBox(height: 14),

          _SectionCard(
            color: cardColor,
            title: 'Financials & Communication',
            icon: Icons.payments_rounded,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Field(
                      controller: _amountReceivedCtrl,
                      label: 'Amount Received (Optional)',
                      hint: '0.00',
                      icon: Icons.download_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                      controller: _amountDueCtrl,
                      label: 'Amount Due (Calculated)',
                      hint: '0.00',
                      icon: Icons.upload_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _whatsappDone,
                onChanged: (val) =>
                    setState(() => _whatsappDone = val ?? false),
                activeColor: AppColors.primary,
                title: Text(
                  'WhatsApp Message Done ✓',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _whatsappDone
                        ? AppColors.success
                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                  ),
                ),
                subtitle: Text(
                  'Confirm follow-up communication sent to customer',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

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

// ─── Product Selection Model ─────────────────────────────────────────────────

class _ProductSelection {
  final int qty;
  final double price;
  const _ProductSelection({required this.qty, required this.price});
  _ProductSelection copyWith({int? qty, double? price}) =>
      _ProductSelection(qty: qty ?? this.qty, price: price ?? this.price);
}

// ─── Product Picker Modal ────────────────────────────────────────────────────

class _ProductPickerSheet extends ConsumerStatefulWidget {
  final Map<String, _ProductSelection> initialSelections;
  final void Function(Map<String, _ProductSelection>) onConfirm;

  const _ProductPickerSheet({
    required this.initialSelections,
    required this.onConfirm,
  });

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<ProductModel>? _filtered;
  late Map<String, _ProductSelection> _selections;
  // price text controllers — one per product name, created lazily
  final Map<String, TextEditingController> _priceCtrls = {};

  @override
  void initState() {
    super.initState();
    _selections = Map.from(widget.initialSelections);
    // pre-populate price controllers for already-selected products
    for (final e in _selections.entries) {
      _priceCtrls[e.key] = TextEditingController(
        text: e.value.price > 0 ? e.value.price.toStringAsFixed(0) : '',
      );
    }
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearch() {
    final allProducts = ref.read(productsProvider).valueOrNull ?? [];
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List<ProductModel>.from(allProducts)
          : allProducts.where((p) => p.name.toLowerCase().contains(q)).toList();
    });
  }

  TextEditingController _priceCtrlFor(String name) {
    return _priceCtrls.putIfAbsent(name, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1D23) : Colors.white;
    final itemBg = isDark ? const Color(0xFF23262D) : const Color(0xFFF8F9FA);

    // Watch products — handle loading & error states
    final productsAsync = ref.watch(productsProvider);
    final allProducts = productsAsync.valueOrNull ?? [];
    // Sync _filtered when products arrive for the first time
    if (_filtered == null && allProducts.isNotEmpty) {
      _filtered = List<ProductModel>.from(allProducts);
    }
    final displayList = _filtered ?? [];

    final double runningTotal = _selections.entries
        .fold(0, (sum, e) => sum + e.value.qty * e.value.price);

    return Container(
      height: MediaQuery.of(context).size.height * 0.91,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medication_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Products & Set Price',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        allProducts.isEmpty
                            ? 'Loading products...'
                            : '${allProducts.length} products available',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selections.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selections.length} • ₹${runningTotal.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by product name...',
                hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 18, color: AppColors.textTertiary),
                        onPressed: _searchCtrl.clear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.border.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)),
              ),
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchCtrl.text.isNotEmpty
                    ? '${displayList.length} results'
                    : '${allProducts.length} products',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Product list
          Expanded(
            child: productsAsync.isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Loading products...'),
                      ],
                    ),
                  )
                : displayList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color: AppColors.textTertiary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No products match your search'
                                  : 'No products available',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, color: AppColors.textTertiary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: displayList.length,
                        itemBuilder: (ctx, i) {
                          final product = displayList[i];
                          final sel = _selections[product.name];
                          final qty = sel?.qty ?? 0;
                          final isSelected = qty > 0;
                          final priceCtrl = _priceCtrlFor(product.name);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.07)
                              : itemBg,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  width: 1)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product name row + stock + qty stepper
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: isSelected
                                                ? AppColors.primary
                                                : (isDark
                                                    ? AppColors.textOnDark
                                                    : AppColors.textPrimary),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        // Stock badge
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: product.stock > 0
                                                    ? AppColors.success
                                                        .withValues(alpha: 0.12)
                                                    : AppColors.error
                                                        .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                product.stock > 0
                                                    ? 'Stock: ${product.stock}'
                                                    : 'Out of stock',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: product.stock > 0
                                                      ? AppColors.success
                                                      : AppColors.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Qty controls
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (qty > 0) ...[
                                        _QtyButton(
                                          icon: Icons.remove_rounded,
                                          onTap: () => setState(() {
                                            if (qty == 1) {
                                              _selections.remove(product.name);
                                              priceCtrl.clear();
                                            } else {
                                              _selections[product.name] =
                                                  sel!.copyWith(qty: qty - 1);
                                            }
                                          }),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            '$qty',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      _QtyButton(
                                        icon: Icons.add_rounded,
                                        onTap: product.stock > 0 && qty >= product.stock
                                            ? () {}
                                            : () => setState(() {
                                                  _selections[product.name] =
                                                      _ProductSelection(
                                                    qty: qty + 1,
                                                    price: double.tryParse(
                                                            priceCtrl.text) ??
                                                        0,
                                                  );
                                                }),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Price input — shown when qty > 0
                              if (isSelected) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.currency_rupee_rounded,
                                        size: 14, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: TextField(
                                        controller: priceCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9.]')),
                                        ],
                                        onChanged: (v) {
                                          final p = double.tryParse(v) ?? 0;
                                          setState(() {
                                            _selections[product.name] =
                                                sel!.copyWith(price: p);
                                          });
                                        },
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accent,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter selling price',
                                          hintStyle: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: AppColors.textTertiary,
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 8),
                                          filled: true,
                                          fillColor: AppColors.accent
                                              .withValues(alpha: 0.06),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                                color: AppColors.accent
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                                color: AppColors.accent
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: AppColors.accent,
                                                width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Subtotal
                                    Text(
                                      '= ₹${(qty * (double.tryParse(priceCtrl.text) ?? 0)).toStringAsFixed(0)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onConfirm(_selections);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _selections.isEmpty
                        ? 'Confirm Selection'
                        : 'Confirm  (${_selections.length} product${_selections.length > 1 ? 's' : ''}  •  ₹${runningTotal.toStringAsFixed(0)})',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

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
