import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/location_permission_helper.dart';
import '../../../providers/attendance_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/call_log_providers.dart';
import '../../common/widgets/success_toast.dart';

class AttendanceCard extends ConsumerStatefulWidget {
  const AttendanceCard({super.key});

  @override
  ConsumerState<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends ConsumerState<AttendanceCard> {
  bool _isProcessing = false;
  String _loadingMessage = '';

  Future<void> _handleStartDuty() async {
    try {
      setState(() {
        _isProcessing = true;
        _loadingMessage = 'Checking GPS...';
      });
      HapticFeedback.mediumImpact();

      // Check/request location permissions first
      await LocationPermissionHelper.checkAndRequestPermission();

      setState(() {
        _loadingMessage = 'Taking Selfie...';
      });

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );

      if (picked == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selfie capture is mandatory to start duty shift.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isProcessing = false;
          _loadingMessage = '';
        });
        return;
      }

      setState(() {
        _loadingMessage = 'Uploading Selfie...';
      });

      final file = File(picked.path);
      final activeUser = ref.read(activeUserProvider);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'selfie_${activeUser?.phoneNumber ?? "unknown"}_$timestamp.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('attendance_selfies/$fileName');
      
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final selfieUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _loadingMessage = 'Starting Shift...';
      });

      final success = await ref.read(activeAttendanceProvider.notifier).startDuty(selfieUrl: selfieUrl);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _loadingMessage = '';
        });
        if (success) {
          SuccessToast.show(
            context,
            message: 'Duty Shift Started! GPS Tracking Active.',
            icon: Icons.play_arrow_rounded,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start duty. Please check GPS/permissions.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Start duty failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting duty: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isProcessing = false;
          _loadingMessage = '';
        });
      }
    }
  }

  Future<void> _confirmEndDuty() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'End Work Shift?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Ending your duty shift will stop background GPS location sharing for the day.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('End Duty', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isProcessing = true;
        _loadingMessage = 'Ending Duty...';
      });
      HapticFeedback.heavyImpact();

      final success = await ref.read(activeAttendanceProvider.notifier).endDuty();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _loadingMessage = '';
        });
        if (success) {
          SuccessToast.show(
            context,
            message: 'Duty Shift Ended. Excellent work today!',
            icon: Icons.check_circle_rounded,
          );
          ref.read(activeUserProvider.notifier).signOut();
          ref.read(callLogsProvider.notifier).loadLogs();
        }
      }
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(activeAttendanceProvider);

    return attendanceAsync.when(
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_off_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Location Permission Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Location access is required for shift attendance & tracking.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await LocationPermissionHelper.checkAndRequestPermission(context: context);
                  ref.read(activeAttendanceProvider.notifier).loadTodayAttendance();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                label: Text(
                  'GRANT LOCATION PERMISSION',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      data: (attendance) {
        final isActive = attendance != null && attendance.isActive;

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: isActive
                      ? AppColors.primaryLight.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? AppColors.success : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? 'SHIFT ACTIVE' : 'DUTY OFF',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isActive ? AppColors.success : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      if (attendance != null)
                        Text(
                          'Started at ${DateFormat('hh:mm a').format(attendance.startTime)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isActive) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (attendance.startSelfieUrl != null)
                          GestureDetector(
                            onTap: () => _showImageDialog(context, attendance.startSelfieUrl!),
                            child: Hero(
                              tag: 'attendance_selfie',
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 1.5),
                                  image: DecorationImage(
                                    image: NetworkImage(attendance.startSelfieUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (attendance.startSelfieUrl != null) const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.my_location_rounded, color: AppColors.accent, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'GPS: ${attendance.startLatitude.toStringAsFixed(4)}, ${attendance.startLongitude.toStringAsFixed(4)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.battery_charging_full_rounded, color: AppColors.success, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Battery: ${attendance.startBattery}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.wifi_rounded, color: AppColors.primaryLight, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Network: ${attendance.startNetwork}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Device: ${attendance.deviceId}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: Colors.white30,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _confirmEndDuty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                          ),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.stop_circle_outlined, size: 20),
                        label: Text(
                          _isProcessing ? _loadingMessage : 'END DUTY SHIFT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Start your day to initiate live GPS tracking and enable visit logging.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _handleStartDuty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                          ),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 22),
                        label: Text(
                          _isProcessing ? _loadingMessage : 'START DUTY SHIFT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
