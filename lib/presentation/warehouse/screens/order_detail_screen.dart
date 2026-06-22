import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/order_providers.dart';
import '../../common/widgets/premium_button.dart';
import '../../common/widgets/success_toast.dart';
import '../../common/widgets/multi_image_viewer.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _logisticsCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();

  bool _isProcessing = false;
  final List<XFile> _packedPhotos = [];
  final List<XFile> _dispatchPhotos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _logisticsCtrl.dispose();
    _trackingCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturePackedPhotoCamera() async {
    HapticFeedback.lightImpact();
    // Prompt warning dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 40),
        title: Text(
          'Verification Required',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          "MANDATORY: You must write the Customer's Name and Today's Date on the bag clearly before taking the photo. Ensure this is visible in the picture!",
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('I have written it', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (image != null && mounted) {
        setState(() => _packedPhotos.add(image));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching camera: $e')));
    }
  }

  Future<void> _capturePackedPhotoGallery() async {
    HapticFeedback.lightImpact();
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (images.isNotEmpty && mounted) {
        setState(() => _packedPhotos.addAll(images));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching gallery: $e')));
    }
  }

  Future<void> _captureDispatchPhotoCamera() async {
    HapticFeedback.lightImpact();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (image != null && mounted) {
        setState(() => _dispatchPhotos.add(image));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching camera: $e')));
    }
  }

  Future<void> _captureDispatchPhotoGallery() async {
    HapticFeedback.lightImpact();
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (images.isNotEmpty && mounted) {
        setState(() => _dispatchPhotos.addAll(images));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching gallery: $e')));
    }
  }

  Widget _buildPhotoSelectionSection({
    required List<XFile> photos,
    required VoidCallback onAddCamera,
    required VoidCallback onAddGallery,
    required void Function(int) onRemove,
    required bool isDark,
  }) {
    if (photos.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAddCamera,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Camera'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAddGallery,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + 1,
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return Center(
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onAddCamera,
                      icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight, size: 18),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: onAddGallery,
                      icon: const Icon(Icons.photo_library_rounded, color: AppColors.primaryLight, size: 18),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final file = photos[index];
          return Stack(
            children: [
              Container(
                width: 90,
                height: 110,
                margin: const EdgeInsets.only(right: 8, top: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(file.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate().fade().scale(duration: 200.ms),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => onRemove(index),
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
    );
  }

  Future<void> _markAsPacked(OrderModel order) async {
    if (_packedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a packed verification photo first!')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final notifier = ref.read(ordersProvider.notifier);
    final List<String> urls = [];

    for (int i = 0; i < _packedPhotos.length; i++) {
      final photo = _packedPhotos[i];
      final fileName = 'packed_${order.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final photoUrl = await notifier.uploadPhoto('status_tracking', photo.path, fileName);

      if (photoUrl == null) {
        setState(() => _isProcessing = false);
        if (mounted) {
          final errStr = notifier.lastUploadError != null ? ': ${notifier.lastUploadError}' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo to Supabase storage$errStr')),
          );
        }
        return;
      }
      urls.add(photoUrl);
    }

    final success = await notifier.updateOrderStatus(
      order.id,
      order.callLogId,
      'packed',
      packedPhotoUrl: urls.join(','),
    );

    setState(() => _isProcessing = false);

    if (success) {
      if (mounted) {
        SuccessToast.show(context, message: 'Order marked as Packed!');
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status. Please try again.')),
        );
      }
    }
  }

  Future<void> _markAsDispatched(OrderModel order) async {
    if (!_formKey.currentState!.validate() || _dispatchPhotos.isEmpty) {
      if (_dispatchPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture a dispatch tracking slip photo first!')),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final notifier = ref.read(ordersProvider.notifier);
    final List<String> urls = [];

    for (int i = 0; i < _dispatchPhotos.length; i++) {
      final photo = _dispatchPhotos[i];
      final fileName = 'dispatch_${order.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final photoUrl = await notifier.uploadPhoto('status_tracking', photo.path, fileName);

      if (photoUrl == null) {
        setState(() => _isProcessing = false);
        if (mounted) {
          final errStr = notifier.lastUploadError != null ? ': ${notifier.lastUploadError}' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload tracking slip photo$errStr')),
          );
        }
        return;
      }
      urls.add(photoUrl);
    }

    final success = await notifier.updateOrderStatus(
      order.id,
      order.callLogId,
      'dispatched',
      dispatchedPhotoUrl: urls.join(','),
      logisticsProvider: _logisticsCtrl.text.trim(),
      trackingId: _trackingCtrl.text.trim(),
    );

    setState(() => _isProcessing = false);

    if (success) {
      if (mounted) {
        SuccessToast.show(context, message: 'Order marked as Dispatched!');
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    // We watch the order state in the provider to get real-time updates
    final ordersAsync = ref.watch(ordersProvider);
    final order = ordersAsync.maybeWhen(
      data: (list) => list.firstWhere((o) => o.id == widget.order.id, orElse: () => widget.order),
      orElse: () => widget.order,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ORDER VALUE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${order.orderValue.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
                const Divider(height: 24),
                _RowInfo(label: 'Customer Name', value: order.customerName),
                const SizedBox(height: 12),
                _RowInfo(label: 'Product Ordered', value: order.product),
                const SizedBox(height: 12),
                _RowInfo(label: 'Order Logged At', value: DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Packing Phase
          if (order.status == 'received') ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PHASE 1: PACKING VERIFICATION',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Take a photo of the packed bag. Write the Customer's Name and Today's Date on the bag clearly before taking the photo.",
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _buildPhotoSelectionSection(
                    photos: _packedPhotos,
                    onAddCamera: _capturePackedPhotoCamera,
                    onAddGallery: _capturePackedPhotoGallery,
                    onRemove: (idx) => setState(() => _packedPhotos.removeAt(idx)),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  PremiumButton(
                    label: 'Mark as Packed',
                    isLoading: _isProcessing,
                    onTap: _packedPhotos.isEmpty || _isProcessing ? null : () => _markAsPacked(order),
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  ),
                ],

              ),
            ),
          ],

          // Dispatch Phase
          if (order.status == 'packed') ...[
            // View Packed Photo
            if (order.packedPhotoUrls.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Packed Verification Completed',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        MultiImageViewerDialog.show(
                          context,
                          imageUrls: order.packedPhotoUrls,
                          title: 'Packed Verification Photos',
                        );
                      },
                      child: Text('View Photo (${order.packedPhotoUrls.length})'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PHASE 2: LOGISTICS & DISPATCH',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _logisticsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Logistics Provider *',
                        hintText: 'e.g. VRL, RTC, Professional, etc.',
                        prefixIcon: Icon(Icons.local_shipping_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Logistics provider required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _trackingCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tracking ID / LR Number *',
                        hintText: 'Enter tracking reference number',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Tracking ID required' : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upload Tracking Slip Photo *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _buildPhotoSelectionSection(
                      photos: _dispatchPhotos,
                      onAddCamera: _captureDispatchPhotoCamera,
                      onAddGallery: _captureDispatchPhotoGallery,
                      onRemove: (idx) => setState(() => _dispatchPhotos.removeAt(idx)),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      label: 'Mark as Dispatched',
                      isLoading: _isProcessing,
                      onTap: _dispatchPhotos.isEmpty || _isProcessing ? null : () => _markAsDispatched(order),
                      icon: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                    ),
                  ],
              ),
            ),
          ),
        ],

        // Fully Dispatched Details
        if (order.status == 'dispatched') ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHIPMENT & DISPATCH DOCUMENTATION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                    letterSpacing: 0.5,
                  ),
                ),
                const Divider(height: 24),
                _RowInfo(label: 'Logistics Provider', value: order.logisticsProvider ?? 'N/A'),
                const SizedBox(height: 12),
                _RowInfo(label: 'Tracking ID / LR Number', value: order.trackingId ?? 'N/A'),
                const SizedBox(height: 20),
                if (order.packedPhotoUrls.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.photo_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          MultiImageViewerDialog.show(
                            context,
                            imageUrls: order.packedPhotoUrls,
                            title: 'Packed Verification Photos',
                          );
                        },
                        child: Text(
                          'View Packed Bag Verification Photo (${order.packedPhotoUrls.length}) 🖼️',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (order.dispatchedPhotoUrls.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.photo_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          MultiImageViewerDialog.show(
                            context,
                            imageUrls: order.dispatchedPhotoUrls,
                            title: 'Logistics Slip Photos',
                          );
                        },
                        child: Text(
                          'View Tracking Slip Photo (${order.dispatchedPhotoUrls.length}) 🖼️',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
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
      ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'received':
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        fg = const Color(0xFF3B82F6);
        break;
      case 'packed':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        break;
      case 'dispatched':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.12);
        fg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;

  const _RowInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
