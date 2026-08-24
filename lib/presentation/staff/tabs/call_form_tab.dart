import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/call_log_model.dart';
import '../../../data/models/product_model.dart';
import '../../../providers/product_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/visit_providers.dart';
import '../../common/widgets/premium_button.dart';
import '../../common/widgets/status_chip_selector.dart';
import '../../common/widgets/success_toast.dart';
import '../widgets/attendance_card.dart';
import '../../../providers/attendance_providers.dart';

const _uuid = Uuid();

class CallFormTab extends ConsumerStatefulWidget {
  const CallFormTab({super.key});

  @override
  ConsumerState<CallFormTab> createState() => _CallFormTabState();
}

class _CallFormTabState extends ConsumerState<CallFormTab> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  final _nameKey = GlobalKey();
  final _mobileKey = GlobalKey();
  final _statusKey = GlobalKey();
  final _productKey = GlobalKey();
  final _remarksKey = GlobalKey();

  final _nameFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _remarksFocus = FocusNode();

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

  File? _capturedImage;
  TimeOfDay _arrivalTime = TimeOfDay.fromDateTime(DateTime.now().subtract(const Duration(minutes: 30)));
  TimeOfDay _departureTime = TimeOfDay.now();
  double? _capturedLat;
  double? _capturedLng;
  bool _isFetchingGps = false;
  String _gpsStatus = 'Captured (Accurate)';

  Map<String, _ProductSelection> _selectedProducts = {};

  @override
  void initState() {
    super.initState();
    _orderCtrl.addListener(_updateAmountDue);
    _amountReceivedCtrl.addListener(_updateAmountDue);
    _fetchGps();
  }

  void _updateAmountDue() {
    final orderVal = double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0;
    double amtReceived = double.tryParse(_amountReceivedCtrl.text.replaceAll(',', '')) ?? 0.0;

    if (orderVal > 0 && amtReceived > orderVal) {
      amtReceived = orderVal;
      final clampedText = orderVal == orderVal.truncateToDouble()
          ? orderVal.toInt().toString()
          : orderVal.toStringAsFixed(2);
      if (_amountReceivedCtrl.text != clampedText) {
        _amountReceivedCtrl.text = clampedText;
        _amountReceivedCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: clampedText.length),
        );
      }
    }

    final amtDue = orderVal - amtReceived;
    final newText = amtDue >= 0 ? amtDue.toStringAsFixed(2) : '0.00';
    if (_amountDueCtrl.text != newText) {
      _amountDueCtrl.text = newText;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nameFocus.dispose();
    _mobileFocus.dispose();
    _remarksFocus.dispose();
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

  Future<void> _scrollToKey(GlobalKey key, {FocusNode? focusNode}) async {
    final ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
      if (focusNode != null) {
        focusNode.requestFocus();
      }
    }
  }

  Future<void> _fetchGps() async {
    if (!mounted) return;
    setState(() {
      _isFetchingGps = true;
      _gpsStatus = 'Locating...';
    });
    try {
      Position? pos;
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 8),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }
        }
      }
      if (pos != null) {
        if (mounted) {
          setState(() {
            _capturedLat = pos!.latitude;
            _capturedLng = pos.longitude;
            _gpsStatus = 'Captured (Accurate)';
            _isFetchingGps = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _gpsStatus = 'GPS Signal Weak';
            _isFetchingGps = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatus = 'GPS Error';
          _isFetchingGps = false;
        });
      }
    }
  }

  String _calculateVisitDuration() {
    final now = DateTime.now();
    final arrivalDt = DateTime(now.year, now.month, now.day, _arrivalTime.hour, _arrivalTime.minute);
    var departureDt = DateTime(now.year, now.month, now.day, _departureTime.hour, _departureTime.minute);
    if (departureDt.isBefore(arrivalDt)) {
      departureDt = departureDt.add(const Duration(days: 1));
    }
    final diffMinutes = departureDt.difference(arrivalDt).inMinutes;
    if (diffMinutes <= 0) return '0 Minutes';
    if (diffMinutes < 60) return '$diffMinutes Minutes';
    final hrs = diffMinutes ~/ 60;
    final mins = diffMinutes % 60;
    return mins > 0 ? '$hrs hr $mins mins' : '$hrs hr';
  }

  Future<void> _takePhoto() async {
    try {
      HapticFeedback.lightImpact();
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _capturedImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('Camera capture failed: $e');
    }
  }

  Widget _buildGpsAutoCapture(BuildContext context, bool isDark) {
    final latStr = _capturedLat?.toStringAsFixed(4) ?? '28.6139';
    final lngStr = _capturedLng?.toStringAsFixed(4) ?? '77.2090';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPS Auto Capture',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'GPS Status: $_gpsStatus',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '[e.g., $latStr, $lngStr]',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isFetchingGps ? null : _fetchGps,
            icon: _isFetchingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            tooltip: 'Refresh GPS',
          ),
        ],
      ),
    );
  }

  Widget _buildVisitTimingSection(BuildContext context, bool isDark, Color cardColor) {
    return _SectionCard(
      color: cardColor,
      title: 'Visit Timing *',
      icon: Icons.access_time_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _arrivalTime,
                  );
                  if (picked != null) setState(() => _arrivalTime = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Arrival Time *',
                    prefixIcon: Icon(Icons.schedule_rounded, size: 18, color: AppColors.textTertiary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _arrivalTime.format(context),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _departureTime,
                  );
                  if (picked != null) setState(() => _departureTime = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Departure Time *',
                    prefixIcon: Icon(Icons.schedule_rounded, size: 18, color: AppColors.textTertiary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _departureTime.format(context),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Visit Duration',
            prefixIcon: Icon(Icons.timer_outlined, size: 18, color: AppColors.textTertiary),
            filled: true,
          ),
          child: Text(
            _calculateVisitDuration(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildPhotoProofSection(BuildContext context, bool isDark, Color cardColor) {
    return _SectionCard(
      color: cardColor,
      title: 'Photo Proof *',
      icon: Icons.camera_alt_rounded,
      children: [
        GestureDetector(
          onTap: _takePhoto,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: _capturedImage != null ? AppColors.success : AppColors.textTertiary.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: _capturedImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius - 1),
                        child: Image.file(
                          _capturedImage!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Retake',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 32, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to capture Mandatory Photo Proof *',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A clear photo of the customer/location is mandatory.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isDark ? Colors.white60 : AppColors.textTertiary,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1);
  }

  Future<void> _submit() async {
    final activeUser = ref.read(activeUserProvider);
    final isField = activeUser != null && activeUser.role == 'staff' && activeUser.isFieldStaff;

    if (isField && _capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mandatory: Photo proof with camera required for visit verification.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final bool statusMissing = !isField && _selectedStatus == null;
    if (statusMissing) {
      setState(() => _statusError = true);
    } else {
      setState(() => _statusError = false);
    }

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || statusMissing) {
      final nameText = _nameCtrl.text.trim();
      final mobileText = _mobileCtrl.text.trim();
      final remarksText = _remarksCtrl.text.trim();

      if (nameText.isEmpty) {
        await _scrollToKey(_nameKey, focusNode: _nameFocus);
        return;
      }

      if (mobileText.isEmpty || mobileText.length != 10) {
        await _scrollToKey(_mobileKey, focusNode: _mobileFocus);
        return;
      }

      if (statusMissing) {
        await _scrollToKey(_statusKey);
        return;
      }

      if (_selectedStatus == 'Order Received') {
        final orderVal = double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0;
        if (_selectedProducts.isEmpty || orderVal <= 0) {
          await _scrollToKey(_productKey);
          _showProductPicker();
          return;
        }
      }

      if (_showCustomRemarksField && remarksText.isEmpty) {
        await _scrollToKey(_remarksKey, focusNode: _remarksFocus);
        return;
      }

      return;
    }

    setState(() => _isSubmitting = true);

    final String productStr = _selectedProducts.isEmpty
        ? ''
        : jsonEncode(
            _selectedProducts.entries
                .map((e) => {'name': e.key, 'qty': e.value.qty, 'price': e.value.price})
                .toList(),
          );

    final String effectiveStatus = isField
        ? (_selectedStatus ?? (_selectedProducts.isNotEmpty ? 'Order Received' : 'Connected'))
        : _selectedStatus!;

    final log = CallLogModel(
      id: _uuid.v4(),
      date: DateTime.now(),
      customerName: _nameCtrl.text.trim(),
      clinicName: _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      place: _placeCtrl.text.trim(),
      product: productStr,
      connectedStatus: effectiveStatus,
      customerResponse: _responseCtrl.text.trim(),
      nextFollowUpDate: _followUpDate,
      orderValue: double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0,
      remarks: _showCustomRemarksField ? _remarksCtrl.text.trim() : '',
      deviceId: ref.read(deviceIdProvider),
      amountReceived: double.tryParse(_amountReceivedCtrl.text.replaceAll(',', '')) ?? 0.0,
      amountDue: double.tryParse(_amountDueCtrl.text.replaceAll(',', '')) ?? 0.0,
      whatsappDone: _whatsappDone,
      standardRemark: _selectedStandardRemark,
      orderStatus: effectiveStatus == 'Order Received' ? 'received' : null,
      orderStatusUpdatedAt: effectiveStatus == 'Order Received' ? DateTime.now() : null,
    );

    final success = await ref.read(callLogsProvider.notifier).addLog(log);

    if (isField) {
      await ref.read(visitsProvider.notifier).logVisit(
        customerName: _nameCtrl.text.trim(),
        customerType: 'doctor',
        address: _placeCtrl.text.trim(),
        remarks: _showCustomRemarksField ? _remarksCtrl.text.trim() : (_selectedStandardRemark ?? _responseCtrl.text.trim()),
        nextFollowUpDate: DateFormat('yyyy-MM-dd').format(_followUpDate),
        photoUrl: _capturedImage?.path,
      );
    }

    setState(() => _isSubmitting = false);

    if (success) {
      _clearForm();
      if (mounted) {
        SuccessToast.show(
          context,
          message: isField ? 'Visit log saved successfully!' : 'Call log saved successfully!',
        );
      }
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
      _capturedImage = null;
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
            final allProducts = ref.watch(productsProvider).valueOrNull ?? [];
            final productObj = allProducts.where((p) => p.name == entry.key).firstOrNull;
            final stock = productObj?.stock ?? 0;
            final avail = stock <= 0 ? 0 : (entry.value.qty <= stock ? entry.value.qty : stock);
            final unavail = entry.value.qty - avail;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    unavail > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                    size: 14,
                    color: unavail > 0 ? AppColors.warning : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                        ),
                        if (unavail > 0 || avail > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              spacing: 4,
                              children: [
                                if (avail > 0)
                                  Text(
                                    '$avail avail',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                if (unavail > 0)
                                  Text(
                                    '${avail > 0 ? "• " : ""}$unavail out of stock',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
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

  Widget _buildBlocker(BuildContext context, bool isDark, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Duty Shift Not Started',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'To comply with attendance tracking regulations, please start your shift first. Starting your shift will verify your attendance with your selfie, device diagnostics, and location coordinates.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text(
                'Selfie Verification',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text(
                'GPS Location Tracking',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text(
                'Battery & Connection Logs',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final attendanceAsync = ref.watch(activeAttendanceProvider);
    final attendance = attendanceAsync.valueOrNull;
    final isShiftActive = attendance != null && attendance.isActive;

    final activeUser = ref.watch(activeUserProvider);
    final isField = activeUser != null && activeUser.role == 'staff' && activeUser.isFieldStaff;

    return Form(
      key: _formKey,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const SizedBox(height: 12),
          const AttendanceCard(),
          const SizedBox(height: 16),
          if (!isShiftActive) ...[
            _buildBlocker(context, isDark, cardColor),
          ] else ...[
            _SectionCard(
              color: cardColor,
              title: isField ? 'Customer Info & Visit Details *' : 'Customer Info',
              icon: Icons.person_rounded,
              children: [
                _Field(
                  key: _nameKey,
                  focusNode: _nameFocus,
                  controller: _nameCtrl,
                  label: isField ? 'Customer/Doctor/Shop Name *' : 'Customer Name *',
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
                  key: _mobileKey,
                  focusNode: _mobileFocus,
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
                  label: isField ? 'Visit Address *' : 'Place / Market Area (Optional)',
                  hint: isField ? 'Address / location details' : 'City, region or address details',
                  icon: Icons.location_on_rounded,
                  minLines: 2,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  validator: isField ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
                ),
                if (isField) ...[
                  const SizedBox(height: 14),
                  _buildGpsAutoCapture(context, isDark),
                ],
              ],
            ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),

            const SizedBox(height: 14),

            if (isField) ...[
              _buildVisitTimingSection(context, isDark, cardColor),
              const SizedBox(height: 14),
              _buildPhotoProofSection(context, isDark, cardColor),
              const SizedBox(height: 14),
            ],

            if (!isField) ...[
              _SectionCard(
                key: _statusKey,
                color: cardColor,
                title: 'Call Status *',
                icon: Icons.signal_cellular_alt_rounded,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Call Status *',
                      prefixIcon: Icon(Icons.signal_cellular_alt_rounded,
                          color: AppColors.textTertiary, size: 20),
                    ),
                    dropdownColor: cardColor,
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    items: kStatusOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt.label,
                        child: Row(
                          children: [
                            Icon(opt.icon, size: 18, color: opt.color),
                            const SizedBox(width: 10),
                            Text(
                              opt.label,
                              style: GoogleFonts.plusJakartaSans(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (s) {
                      if (s != null) {
                        setState(() {
                          _selectedStatus = s;
                          _statusError = false;
                          _updateAmountDue();
                        });
                      }
                    },
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
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
              const SizedBox(height: 14),
            ],

            _SectionCard(
              key: _productKey,
              color: cardColor,
              title: 'Product (Optional)',
              icon: Icons.medication_rounded,
              children: [
                _buildProductSelector(context, isDark, cardColor),
              ],
            ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.1),

            const SizedBox(height: 14),

            _SectionCard(
              color: cardColor,
              title: 'Remarks & Logs *',
              icon: Icons.notes_rounded,
              children: [
                _Field(
                  controller: _responseCtrl,
                  label: 'Customer Response / Remarks *',
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
                    key: _remarksKey,
                    focusNode: _remarksFocus,
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
              title: 'Financials & Communication',
              icon: Icons.payments_rounded,
              children: [
                // Order Value (Read-only / Auto-calculated from selected products)
                TextFormField(
                  controller: _orderCtrl,
                  readOnly: true,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Order Value',
                    hintText: '0.00',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.textTertiary,
                      fontSize: 18,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Text(
                        '₹',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                    filled: true,
                    fillColor: AppColors.accent.withValues(alpha: 0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (_selectedStatus == 'Order Received') {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required for Order Received';
                      }
                      final val = double.tryParse(v.replaceAll(',', ''));
                      if (val == null || val <= 0) {
                        return 'Must select products to generate order value';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _amountReceivedCtrl,
                        label: 'Received (Optional)',
                        hint: '0.00',
                        icon: Icons.download_rounded,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final orderVal = double.tryParse(_orderCtrl.text.replaceAll(',', '')) ?? 0.0;
                            final amtRec = double.tryParse(v.replaceAll(',', '')) ?? 0.0;
                            if (orderVal > 0 && amtRec > orderVal) {
                              return 'Cannot exceed Order Value (₹${orderVal.toStringAsFixed(0)})';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Field(
                        controller: _amountDueCtrl,
                        label: 'Due',
                        hint: '0.00',
                        icon: Icons.upload_rounded,
                        readOnly: true,
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
            ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.1),

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
            ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            PremiumButton(
              label: isField ? 'Submit Visit Log' : 'Save Call Log',
              isLoading: _isSubmitting,
              onTap: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.2),
          ],
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
  final Map<String, TextEditingController> _qtyCtrls = {};

  @override
  void initState() {
    super.initState();
    _selections = Map.from(widget.initialSelections);
    // pre-populate price & quantity controllers for already-selected products
    for (final e in _selections.entries) {
      _priceCtrls[e.key] = TextEditingController(
        text: e.value.price > 0 ? e.value.price.toStringAsFixed(0) : '',
      );
      _qtyCtrls[e.key] = TextEditingController(
        text: e.value.qty > 0 ? '${e.value.qty}' : '',
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
    for (final c in _qtyCtrls.values) {
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

  TextEditingController _qtyCtrlFor(String name, int qty) {
    return _qtyCtrls.putIfAbsent(
      name,
      () => TextEditingController(text: qty > 0 ? '$qty' : ''),
    );
  }

  void _setQuantity(ProductModel product, int newQty, TextEditingController priceCtrl) {
    setState(() {
      if (newQty <= 0) {
        _selections.remove(product.name);
        _priceCtrls[product.name]?.clear();
        _qtyCtrls[product.name]?.clear();
      } else {
        final price = double.tryParse(priceCtrl.text) ?? 0;
        _selections[product.name] = _ProductSelection(qty: newQty, price: price);
        final qCtrl = _qtyCtrlFor(product.name, newQty);
        final newText = '$newQty';
        if (qCtrl.text != newText) {
          qCtrl.text = newText;
          qCtrl.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
        }
      }
    });
  }

  void _onQtyInput(ProductModel product, String text, TextEditingController priceCtrl) {
    final val = int.tryParse(text) ?? 0;
    setState(() {
      final sel = _selections[product.name];
      final price = sel?.price ?? (double.tryParse(priceCtrl.text) ?? 0);
      _selections[product.name] = _ProductSelection(qty: val, price: price);
    });
  }

  Widget _buildStockBadges(int stock, int qty) {
    if (qty == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: stock > 0
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          stock > 0 ? 'Stock: $stock' : 'Out of stock',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: stock > 0 ? AppColors.success : AppColors.error,
          ),
        ),
      );
    }

    final available = stock <= 0 ? 0 : (qty <= stock ? qty : stock);
    final unavailable = qty - available;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stock > 0 && qty <= stock) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Stock: $stock',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 10, color: AppColors.success),
                const SizedBox(width: 3),
                Text(
                  '$qty Avail',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ] else if (stock <= 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Out of stock',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 10, color: AppColors.error),
                const SizedBox(width: 3),
                Text(
                  '$unavailable Needed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Partial stock: qty > stock and stock > 0
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 10, color: AppColors.success),
                const SizedBox(width: 3),
                Text(
                  '$available Avail',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 10, color: AppColors.error),
                const SizedBox(width: 3),
                Text(
                  '$unavailable Out of stock',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
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

    final activeEntries = _selections.entries.where((e) => e.value.qty > 0);
    final int activeCount = activeEntries.length;
    final double runningTotal = activeEntries
        .fold(0.0, (sum, e) => sum + e.value.qty * e.value.price);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
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
                if (activeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$activeCount • ₹${runningTotal.toStringAsFixed(0)}',
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
                          final isSelected = _selections.containsKey(product.name);
                          final sel = _selections[product.name];
                          final qty = sel?.qty ?? 0;
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        const SizedBox(height: 4),
                                        // Stock badges with live status breakdown
                                        _buildStockBadges(product.stock, qty),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Qty controls with + / - and manual text entry
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected) ...[
                                        _QtyButton(
                                          icon: Icons.remove_rounded,
                                          onTap: () => _setQuantity(product, qty - 1, priceCtrl),
                                        ),
                                        Container(
                                          width: 48,
                                          height: 32,
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkSurface : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppColors.primary.withValues(alpha: 0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: TextField(
                                            controller: _qtyCtrlFor(product.name, qty),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            scrollPadding: const EdgeInsets.only(bottom: 120),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                            ],
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                                              border: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                            ),
                                            onChanged: (v) => _onQtyInput(product, v, priceCtrl),
                                          ),
                                        ),
                                      ],
                                      _QtyButton(
                                        icon: Icons.add_rounded,
                                        onTap: () => _setQuantity(product, qty + 1, priceCtrl),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Price input — shown when isSelected
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
                                        scrollPadding: const EdgeInsets.only(bottom: 120),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9.]')),
                                        ],
                                        onChanged: (v) {
                                          final p = double.tryParse(v) ?? 0;
                                          setState(() {
                                            if (sel != null) {
                                              _selections[product.name] =
                                                  sel.copyWith(price: p);
                                            }
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
                    final cleanSelections = Map<String, _ProductSelection>.from(_selections)
                      ..removeWhere((key, value) => value.qty <= 0);
                    widget.onConfirm(cleanSelections);
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
                    activeCount == 0
                        ? 'Confirm Selection'
                        : 'Confirm  ($activeCount product${activeCount > 1 ? 's' : ''}  •  ₹${runningTotal.toStringAsFixed(0)})',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
    super.key,
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
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;

  const _Field({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
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
