import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/call_log_model.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/order_providers.dart';
import '../../common/widgets/multi_image_viewer.dart';
import '../../../data/models/telecaller_model.dart';
import '../../../core/utils/product_formatter.dart';
import '../../../providers/auth_providers.dart';

class AdminLogCard extends ConsumerWidget {
  final CallLogModel log;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AdminLogCard({
    super.key,
    required this.log,
    required this.index,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = AppColors.statusColor(log.connectedStatus);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final isUrgent = _isFollowUpUrgent(log.nextFollowUpDate);

    final OrderModel? orderDetail = log.product.isNotEmpty
        ? ref.watch(orderDetailProvider(log.id))
        : null;

    final telecallersAsync = ref.watch(telecallersProvider);
    final telecallers = telecallersAsync.value ?? [];
    final staffName = _getStaffName(log.deviceId, telecallers);

    final isOverdue = log.product.isNotEmpty &&
        (orderDetail == null || orderDetail.status.toLowerCase() == 'received') &&
        DateTime.now().difference(log.date).inHours >= 24;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isUrgent
              ? AppColors.accent.withValues(alpha: 0.4)
              : (isDark ? AppColors.borderDark : AppColors.border),
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon(log.connectedStatus),
                      color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              log.customerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textOnDark
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (log.orderValue > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '₹${_fmt(log.orderValue)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (log.clinicName != null && log.clinicName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.local_hospital_rounded,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              log.clinicName!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              size: 12, color: AppColors.primaryLight),
                          const SizedBox(width: 4),
                          Text(
                            'Staff: $staffName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _CopyablePhone(mobile: log.mobile),
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              log.place,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (log.product.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.medication_rounded,
                                  size: 12, color: AppColors.primaryLight),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatProductLabel(log.product),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textOnDark : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Pills row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Pill(label: log.connectedStatus, color: statusColor),
                      if (log.product.isNotEmpty)
                        _Pill(
                          label: '📦 ${(orderDetail?.status ?? 'received').toUpperCase()}',
                          color: _orderStatusColor(orderDetail?.status ?? 'received'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isUrgent)
                  _Pill(label: '🔔 Follow-up', color: AppColors.accent)
                else
                  Text(
                    '📅 ${DateFormat('dd MMM').format(log.nextFollowUpDate)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            if (log.customerResponse.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                log.customerResponse,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(log.date),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            if (isOverdue) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SLA Alert: Order not packed within 24 hours!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .shimmer(delay: 2000.ms, duration: 1200.ms, color: AppColors.error.withValues(alpha: 0.15)),
            ],
            
            // Packed and Dispatched photo links for Admin
            if (orderDetail != null &&
                (orderDetail.status == 'packed' ||
                    orderDetail.status == 'dispatched')) ...[
              const SizedBox(height: 8),
              if (orderDetail.packedPhotoUrls.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.photo_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => MultiImageViewerDialog.show(
                          context,
                          imageUrls: orderDetail.packedPhotoUrls,
                          title: 'Packed Verification Photos'),
                      child: Text(
                        'View Packed Bag Photo (${orderDetail.packedPhotoUrls.length}) 🖼️',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (orderDetail.status == 'dispatched') ...[
                if (orderDetail.dispatchedPhotoUrls.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.photo_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => MultiImageViewerDialog.show(
                            context,
                            imageUrls: orderDetail.dispatchedPhotoUrls,
                            title: 'Logistics Slip Photos'),
                        child: Text(
                          'View Tracking Slip Photo (${orderDetail.dispatchedPhotoUrls.length}) 🖼️',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ],

            // Action buttons
            if (onEdit != null || onDelete != null || orderDetail?.status == 'packed') ...[
              const SizedBox(height: 10),
              Divider(
                color: isDark ? AppColors.borderDark : AppColors.border,
                height: 1,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    _ActionButton(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      color: AppColors.primary,
                      onTap: onEdit!,
                    ),
                  if (orderDetail?.status == 'packed') ...[
                    if (onEdit != null) const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.local_shipping_rounded,
                      label: 'Dispatch',
                      color: AppColors.success,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _DispatchSheet(
                          orderId: orderDetail!.id,
                          callLogId: log.id,
                          customerName: log.customerName,
                        ),
                      ),
                    ),
                  ],
                  if (onDelete != null) ...[
                    if (onEdit != null || orderDetail?.status == 'packed')
                      const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: AppColors.error,
                      onTap: onDelete!,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 40 * (index % 12)))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08);
  }

  bool _isFollowUpUrgent(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayAfter = DateTime(now.year, now.month, now.day + 2);
    return date.isAfter(today.subtract(const Duration(days: 1))) &&
        date.isBefore(dayAfter);
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _getStaffName(String deviceId, List<TelecallerModel> telecallers) {
    if (telecallers.isEmpty) {
      return _fallbackStaffName(deviceId);
    }
    for (final tc in telecallers) {
      final formattedTcId = tc.phoneNumber.length == 10
          ? '00000000-0000-0000-0000-${tc.phoneNumber.padLeft(12, '0')}'
          : tc.phoneNumber;
      if (deviceId == formattedTcId || deviceId == tc.phoneNumber) {
        return tc.name;
      }
    }
    return _fallbackStaffName(deviceId);
  }

  String _fallbackStaffName(String deviceId) {
    final match = RegExp(r'(\d{10})$').firstMatch(deviceId);
    if (match != null) {
      return match.group(1)!;
    }
    if (deviceId.length > 8) {
      return deviceId.substring(0, 8);
    }
    return deviceId;
  }

  String _formatProductLabel(String product) {
    return ProductFormatter.format(product);
  }

  Color _orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return const Color(0xFF3B82F6); // Blue
      case 'packed':
        return const Color(0xFFF59E0B); // Orange
      case 'dispatched':
        return const Color(0xFF10B981); // Green
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return Icons.check_circle_rounded;
      case 'busy':
        return Icons.phone_in_talk_rounded;
      case 'no answer':
        return Icons.phone_missed_rounded;
      case 'call back':
        return Icons.phone_callback_rounded;
      case 'not interested':
        return Icons.thumb_down_rounded;
      case 'interested':
        return Icons.thumb_up_rounded;
      default:
        return Icons.phone_rounded;
    }
  }
}

// ─── Dispatch Sheet ───────────────────────────────────────────────────────────

class _DispatchSheet extends ConsumerStatefulWidget {
  final String orderId;
  final String callLogId;
  final String customerName;

  const _DispatchSheet({
    required this.orderId,
    required this.callLogId,
    required this.customerName,
  });

  @override
  ConsumerState<_DispatchSheet> createState() => _DispatchSheetState();
}

class _DispatchSheetState extends ConsumerState<_DispatchSheet> {
  final _logisticsCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final List<File> _images = [];
  bool _uploading = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _logisticsCtrl.dispose();
    _trackingCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final pickedList = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1920);
        if (pickedList.isNotEmpty && mounted) {
          setState(() {
            _images.addAll(pickedList.map((x) => File(x.path)));
          });
        }
      } else {
        final picked = await _picker.pickImage(
            source: source, imageQuality: 80, maxWidth: 1920);
        if (picked != null && mounted) {
          setState(() {
            _images.add(File(picked.path));
          });
        }
      }
    } catch (_) {}
  }

  void _showAddImageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight),
                title: Text('Take Photo', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryLight),
                title: Text('Choose from Gallery', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDispatch() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    String? dispatchPhotoUrl;
    if (_images.isNotEmpty) {
      final List<String> urls = [];
      final notifier = ref.read(ordersProvider.notifier);

      for (int i = 0; i < _images.length; i++) {
        final file = _images[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'dispatched_${widget.orderId}_${timestamp}_$i.jpg';
        final photoUrl = await notifier.uploadPhoto('status_tracking', file.path, fileName);
        
        if (photoUrl == null) {
          if (mounted) {
            setState(() => _uploading = false);
            final errStr = notifier.lastUploadError != null ? ': ${notifier.lastUploadError}' : '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Photo $i upload failed$errStr')),
            );
          }
          return;
        }
        urls.add(photoUrl);
      }
      dispatchPhotoUrl = urls.join(',');
    }

    final logistics = _logisticsCtrl.text.trim();
    final tracking = _trackingCtrl.text.trim();

    final success = await ref.read(ordersProvider.notifier).updateOrderStatus(
          widget.orderId,
          widget.callLogId,
          'dispatched',
          dispatchedPhotoUrl: dispatchPhotoUrl,
          logisticsProvider: logistics.isNotEmpty ? logistics : null,
          trackingId: tracking.isNotEmpty ? tracking : null,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Order dispatched successfully!'
                : 'Failed to update. Try again.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: AppColors.success, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark as Dispatched',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textOnDark
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.customerName,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Divider(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                  height: 1),
              const SizedBox(height: 16),

              // Logistics info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOGISTICS DETAILS (optional)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Logistics provider
                    TextField(
                      controller: _logisticsCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Logistics Provider',
                        hintText: 'e.g. Blue Dart, DTDC',
                        prefixIcon: const Icon(Icons.local_shipping_rounded,
                            size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tracking ID
                    TextField(
                      controller: _trackingCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Tracking / AWB Number',
                        hintText: 'Enter tracking ID',
                        prefixIcon: Icon(Icons.tag_rounded, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Photo section
                    Text(
                      'DISPATCH SLIP PHOTO (optional)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_images.isNotEmpty)
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _images.length) {
                              // Add More Card
                              return Center(
                                child: InkWell(
                                  onTap: () => _showAddImageOptions(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 90,
                                    height: 110,
                                    margin: const EdgeInsets.only(left: 8, top: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_rounded, color: AppColors.primaryLight, size: 22),
                                        SizedBox(height: 4),
                                        Text(
                                          'Add More',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final file = _images[index];
                            return Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 110,
                                  margin: const EdgeInsets.only(right: 8, top: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ).animate().fade().scale(duration: 200.ms),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _images.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _PhotoBtn(
                              icon: Icons.camera_alt_rounded,
                              label: 'Camera',
                              onTap: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PhotoBtn(
                              icon: Icons.photo_library_rounded,
                              label: 'Gallery',
                              onTap: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Confirm button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _confirmDispatch,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded,
                              size: 18),
                      label: Text(
                        _uploading
                            ? 'Processing...'
                            : 'Confirm Dispatch',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.success.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.success, size: 26),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyablePhone extends StatelessWidget {
  final String mobile;
  const _CopyablePhone({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: mobile));
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$mobile copied',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_rounded, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            mobile,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.copy_rounded, size: 10, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
