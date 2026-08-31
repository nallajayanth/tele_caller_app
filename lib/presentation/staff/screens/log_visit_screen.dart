import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../providers/visit_providers.dart';
import '../../common/widgets/premium_button.dart';
import '../../common/widgets/success_toast.dart';

class LogVisitScreen extends ConsumerStatefulWidget {
  const LogVisitScreen({super.key});

  @override
  ConsumerState<LogVisitScreen> createState() => _LogVisitScreenState();
}

class _LogVisitScreenState extends ConsumerState<LogVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  String _customerType = 'doctor'; // 'doctor', 'distributor', 'medical_shop'
  File? _capturedImage;
  bool _isSaving = false;

  TimeOfDay _arrivalTime = TimeOfDay.fromDateTime(DateTime.now().subtract(const Duration(minutes: 30)));
  TimeOfDay _departureTime = TimeOfDay.now();

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _remarksCtrl.dispose();
    _followUpCtrl.dispose();
    super.dispose();
  }

  Future<void> _takeLiveCameraPhoto() async {
    try {
      HapticFeedback.lightImpact();
      final picker = ImagePicker();
      // Mandatory live camera capture (SRS #5: Gallery pick blocked)
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 60,
      );

      if (picked != null) {
        setState(() {
          _capturedImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('Camera capture failed: $e');
    }
  }

  Future<void> _submitVisit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mandatory: Photo proof with camera required for visit verification.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final arrivalDateTime = DateTime(now.year, now.month, now.day, _arrivalTime.hour, _arrivalTime.minute);
    var departureDateTime = DateTime(now.year, now.month, now.day, _departureTime.hour, _departureTime.minute);
    if (departureDateTime.isBefore(arrivalDateTime)) {
      departureDateTime = departureDateTime.add(const Duration(days: 1));
    }
    final duration = departureDateTime.difference(arrivalDateTime).inMinutes;

    String? photoBase64;
    if (_capturedImage != null) {
      try {
        final bytes = await _capturedImage!.readAsBytes();
        photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (e) {
        debugPrint('Error base64 encoding photo in UI: $e');
      }
    }

    final success = await ref.read(visitsProvider.notifier).logVisit(
          customerName: _nameCtrl.text.trim(),
          customerType: _customerType,
          address: _addressCtrl.text.trim(),
          remarks: _remarksCtrl.text.trim(),
          nextFollowUpDate: _followUpCtrl.text.trim().isNotEmpty ? _followUpCtrl.text.trim() : null,
          photoUrl: photoBase64 ?? _capturedImage!.path,
          arrivalTime: arrivalDateTime,
          departureTime: departureDateTime,
          visitDurationMinutes: duration,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        SuccessToast.show(
          context,
          message: 'Visit Logged Successfully!',
          icon: Icons.verified_rounded,
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log visit. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Log Field Visit',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Type Selector
            Text(
              'VISIT TYPE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(
                  label: 'Doctor',
                  icon: Icons.medical_services_rounded,
                  selected: _customerType == 'doctor',
                  onTap: () => setState(() => _customerType = 'doctor'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Pharmacy',
                  icon: Icons.local_pharmacy_rounded,
                  selected: _customerType == 'medical_shop',
                  onTap: () => setState(() => _customerType = 'medical_shop'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Distributor',
                  icon: Icons.store_rounded,
                  selected: _customerType == 'distributor',
                  onTap: () => setState(() => _customerType = 'distributor'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Doctor / Shop / Customer Name *',
                prefixIcon: Icon(Icons.person_pin_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressCtrl,
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Address / Location Details *',
                prefixIcon: Icon(Icons.location_city_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _remarksCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Visit Remarks / Minutes *',
                prefixIcon: Icon(Icons.note_alt_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _followUpCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Next Follow-up Date (Optional)',
                prefixIcon: Icon(Icons.calendar_month_rounded),
                border: OutlineInputBorder(),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 3)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                );
                if (date != null) {
                  _followUpCtrl.text = DateFormat('yyyy-MM-dd').format(date);
                }
              },
            ),
            const SizedBox(height: 20),
            _buildVisitTimingSection(context, Theme.of(context).brightness == Brightness.dark),
            const SizedBox(height: 24),

            // Mandatory Photo Verification Card (SRS #5)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: _capturedImage == null ? AppColors.error.withValues(alpha: 0.5) : AppColors.success,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _capturedImage != null ? Icons.check_circle_rounded : Icons.photo_camera_rounded,
                        color: _capturedImage != null ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Geo-Tagged Photo Proof *',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: _capturedImage != null ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mandatory camera photo with embedded GPS coordinates & timestamp.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (_capturedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_capturedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _takeLiveCameraPhoto,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(_capturedImage == null ? 'Capture Live Photo' : 'Retake Camera Photo'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            PremiumButton(
              label: 'Submit Visit Log',
              isLoading: _isSaving,
              onTap: _isSaving ? null : _submitVisit,
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitTimingSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VISIT TIMING *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
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
                    prefixIcon: Icon(Icons.schedule_rounded, size: 18),
                    border: OutlineInputBorder(),
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
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
                    prefixIcon: Icon(Icons.schedule_rounded, size: 18),
                    border: OutlineInputBorder(),
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
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
            prefixIcon: Icon(Icons.timer_outlined, size: 18),
            border: OutlineInputBorder(),
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
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
