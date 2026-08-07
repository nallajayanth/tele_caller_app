import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/call_log_model.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/product_providers.dart';
import '../../common/widgets/multi_image_viewer.dart';

class ActivityLogCard extends ConsumerStatefulWidget {
  final CallLogModel log;
  final int index;

  const ActivityLogCard({super.key, required this.log, required this.index});

  @override
  ConsumerState<ActivityLogCard> createState() => _ActivityLogCardState();
}

class _ActivityLogCardState extends ConsumerState<ActivityLogCard> {
  bool _expanded = false;


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final log = widget.log;
    final statusColor = AppColors.statusColor(log.connectedStatus);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    // Check order detail if status is order received
    final OrderModel? orderDetail = log.product.isNotEmpty
        ? ref.watch(orderDetailProvider(log.id))
        : null;

    final isOverdue = log.product.isNotEmpty &&
        (orderDetail == null || orderDetail.status.toLowerCase() == 'received') &&
        DateTime.now().difference(log.date).inHours >= 24;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _statusIcon(log.connectedStatus),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.customerName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                log.place,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CopyablePhone(mobile: log.mobile),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (log.orderValue > 0)
                        Text(
                          '₹${_formatCurrency(log.orderValue)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      const SizedBox(height: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status + date row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Pill(label: log.connectedStatus, color: statusColor),
                        _Pill(
                          label: '📅 ${DateFormat('dd MMM').format(log.nextFollowUpDate)}',
                          color: AppColors.info,
                        ),
                        if (log.product.isNotEmpty)
                          _Pill(
                            label: '📦 ${(orderDetail?.status ?? 'received').toUpperCase()}',
                            color: _orderStatusColor(orderDetail?.status ?? 'received'),
                          ),
                        if (log.whatsappDone)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0x2210B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: Color(0xFF10B981),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('hh:mm a').format(log.date),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded details
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              child: _expanded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            color: isDark ? AppColors.borderDark : AppColors.border,
                            height: 16,
                          ),
                          if (log.clinicName != null && log.clinicName!.isNotEmpty) ...[
                            _DetailRow(
                              icon: Icons.local_hospital_rounded,
                              label: 'Clinic Name',
                              value: log.clinicName!,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (log.product.isNotEmpty) ...[
                            _buildProductDetailRow(context, log.product),
                            const SizedBox(height: 10),
                          ],
                          if (log.customerResponse.isNotEmpty) ...[
                            _DetailRow(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: 'Response',
                              value: log.customerResponse,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (log.standardRemark != null && log.standardRemark!.isNotEmpty) ...[
                            _DetailRow(
                              icon: Icons.feedback_rounded,
                              label: 'Standard Remark',
                              value: log.standardRemark!,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (log.remarks.isNotEmpty) ...[
                            _DetailRow(
                              icon: Icons.edit_note_rounded,
                              label: 'Remarks',
                              value: log.remarks,
                            ),
                            const SizedBox(height: 10),
                          ],
                          // Financials row (Order Received only)
                          if (log.connectedStatus == 'Order Received') ...[
                            _DetailRow(
                              icon: Icons.payments_rounded,
                              label: 'Financials',
                              value:
                                  'Received: ₹${log.amountReceived.toStringAsFixed(2)}  |  Due: ₹${log.amountDue.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 10),
                          ],
                          // Order tracking section (any log that has products)
                          if (log.product.isNotEmpty) ...[
                            Divider(
                                color: isDark ? AppColors.borderDark : AppColors.border,
                                height: 16),
                            Row(
                              children: [
                                Text(
                                  'Order Tracking',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _orderStatusColor(
                                            orderDetail?.status ?? 'received')
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    (orderDetail?.status ?? 'received')
                                        .toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _orderStatusColor(
                                          orderDetail?.status ?? 'received'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (isOverdue) ...[
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
                                        'SLA Alert: Pack this order immediately (exceeded 24 hours)!',
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
                              const SizedBox(height: 10),
                            ],
                            // Mark as Packed button — shown when status is still received
                            if (orderDetail == null ||
                                orderDetail.status == 'received')
                              GestureDetector(
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => _PackingImageSheet(
                                      log: log, order: orderDetail),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.inventory_2_rounded,
                                          size: 16,
                                          color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Mark as Packed',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.camera_alt_rounded,
                                          size: 14,
                                          color: Color(0xFFF59E0B)),
                                    ],
                                  ),
                                ),
                              ),

                            // Mark as Dispatched button — shown when status is packed
                            if (orderDetail != null &&
                                orderDetail.status == 'packed') ...[
                              GestureDetector(
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => _DispatchImageSheet(
                                      log: log, order: orderDetail),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.local_shipping_rounded,
                                          size: 16,
                                          color: Color(0xFF10B981)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Mark as Dispatched',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.camera_alt_rounded,
                                          size: 14,
                                          color: Color(0xFF10B981)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            // Packed photo link
                            if (orderDetail != null &&
                                (orderDetail.status == 'packed' ||
                                    orderDetail.status ==
                                        'dispatched')) ...[
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
                                          decoration:
                                              TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (orderDetail.status == 'dispatched') ...[
                                _DetailRow(
                                  icon: Icons.local_shipping_rounded,
                                  label: 'Logistics Provider',
                                  value:
                                      orderDetail.logisticsProvider ?? 'N/A',
                                ),
                                const SizedBox(height: 10),
                                _DetailRow(
                                  icon: Icons.tag_rounded,
                                  label: 'Tracking ID',
                                  value:
                                      orderDetail.trackingId ?? 'N/A',
                                ),
                                const SizedBox(height: 10),
                                if (orderDetail.dispatchedPhotoUrls.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.photo_rounded,
                                          size: 14,
                                          color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => MultiImageViewerDialog.show(
                                            context,
                                            imageUrls: orderDetail.dispatchedPhotoUrls,
                                            title: 'Logistics Slip Photos'),
                                        child: Text(
                                          'View Tracking Slip Photo (${orderDetail.dispatchedPhotoUrls.length}) 🖼️',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: AppColors.primaryLight,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ],
                          ],
                          _DetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Logged At',
                            value: DateFormat('dd MMM yyyy, hh:mm a').format(log.date),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * widget.index))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.12);
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return Icons.check_circle_rounded;
      case 'order received':
        return Icons.shopping_bag_rounded;
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

  String _formatCurrency(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }


  Widget _buildProductDetailRow(BuildContext context, String productStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allProducts = ref.watch(productsProvider).valueOrNull ?? [];
    final items = _parseProductItems(productStr);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.medication_rounded, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              ...items.map((item) {
                final productObj = allProducts
                    .where((p) => p.name.trim().toLowerCase() == item.name.trim().toLowerCase())
                    .firstOrNull;
                final stock = productObj?.stock ?? 0;
                final avail = stock <= 0 ? 0 : (item.qty <= stock ? item.qty : stock);
                final unavail = item.qty - avail;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.name} × ${item.qty}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (avail > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: AppColors.success.withValues(alpha: 0.25), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        size: 10, color: AppColors.success),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$avail Available',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (unavail > 0) ...[
                              if (avail > 0) const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: AppColors.error.withValues(alpha: 0.25), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        size: 10, color: AppColors.error),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$unavail Out of stock',
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
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  List<_ProductItemLog> _parseProductItems(String raw) {
    if (raw.trim().isEmpty) return [];
    final trimmed = raw.trim();

    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map) {
              final name = (e['name'] ?? e['product_name'] ?? 'Product').toString();
              final qty = (e['qty'] ?? e['quantity'] ?? 1) as num;
              return _ProductItemLog(name: name, qty: qty.toInt());
            }
            return _ProductItemLog(name: e.toString(), qty: 1);
          }).toList();
        } else if (decoded is Map) {
          final name = (decoded['name'] ?? decoded['product_name'] ?? 'Product').toString();
          final qty = (decoded['qty'] ?? decoded['quantity'] ?? 1) as num;
          return [_ProductItemLog(name: name, qty: qty.toInt())];
        }
      } catch (_) {}
    }

    final lines = trimmed.split(RegExp(r'[\r\n,]+'));
    final items = <_ProductItemLog>[];

    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final match = RegExp(r'^(.+?)\s*[×x]\s*(\d+)$', caseSensitive: false).firstMatch(l);
      if (match != null) {
        final name = match.group(1)!.trim();
        final qty = int.tryParse(match.group(2)!) ?? 1;
        items.add(_ProductItemLog(name: name, qty: qty));
      } else {
        items.add(_ProductItemLog(name: l, qty: 1));
      }
    }

    return items;
  }
}

// ─── Packing Image Bottom Sheet ───────────────────────────────────────────────

class _PackingImageSheet extends ConsumerStatefulWidget {
  final CallLogModel log;
  final OrderModel? order;

  const _PackingImageSheet({required this.log, this.order});

  @override
  ConsumerState<_PackingImageSheet> createState() => _PackingImageSheetState();
}

class _PackingImageSheetState extends ConsumerState<_PackingImageSheet> {
  final List<File> _images = [];
  bool _uploading = false;
  final _picker = ImagePicker();

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

  Future<void> _confirmPacked() async {
    if (_images.isEmpty || _uploading) return;
    setState(() => _uploading = true);

    final errorStr = await ref
        .read(ordersProvider.notifier)
        .ensureOrderAndMarkPacked(
          callLogId: widget.log.id,
          customerName: widget.log.customerName,
          product: widget.log.product,
          orderValue: widget.log.orderValue,
          deviceId: widget.log.deviceId,
          imageFilePaths: _images.map((f) => f.path).toList(),
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorStr == null ? 'Order marked as Packed!' : 'Upload failed: $errorStr',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: errorStr == null ? AppColors.success : AppColors.error,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),

            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: Color(0xFFF59E0B), size: 28),
            ),
            const SizedBox(height: 12),

            Text(
              'Mark as Packed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload photos of the packed order as proof',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Image preview or picker buttons
            if (_images.isNotEmpty)
              Container(
                height: 130,
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _ImageSourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImageSourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Confirm button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _images.isNotEmpty && !_uploading
                        ? _confirmPacked
                        : null,
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _uploading
                          ? 'Uploading...'
                          : 'Confirm & Mark Packed',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _images.isNotEmpty
                          ? const Color(0xFFF59E0B)
                          : AppColors.textTertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dispatch Image Bottom Sheet ──────────────────────────────────────────────

class _DispatchImageSheet extends ConsumerStatefulWidget {
  final CallLogModel log;
  final OrderModel? order;

  const _DispatchImageSheet({required this.log, this.order});

  @override
  ConsumerState<_DispatchImageSheet> createState() => _DispatchImageSheetState();
}

class _DispatchImageSheetState extends ConsumerState<_DispatchImageSheet> {
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

  Future<void> _confirmDispatched() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    String? dispatchPhotoUrl;
    if (_images.isNotEmpty) {
      final List<String> urls = [];
      final notifier = ref.read(ordersProvider.notifier);

      for (int i = 0; i < _images.length; i++) {
        final file = _images[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'dispatched_${widget.order?.id ?? widget.log.id}_${timestamp}_$i.jpg';
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
          widget.order?.id ?? widget.log.id,
          widget.log.id,
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
                ? 'Order marked as Dispatched!'
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(height: 12),

              Text(
                'Mark as Dispatched',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload photos of logistics receipt/slip as proof',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Logistics Details Inputs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _logisticsCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Logistics Provider (optional)',
                        hintText: 'e.g. Blue Dart, DTDC',
                        prefixIcon: Icon(Icons.local_shipping_rounded, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _trackingCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Tracking / AWB Number (optional)',
                        hintText: 'Enter tracking ID',
                        prefixIcon: Icon(Icons.tag_rounded, size: 18),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Image preview or picker buttons
              if (_images.isNotEmpty)
                Container(
                  height: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ImageSourceButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Camera',
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ImageSourceButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Confirm button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _images.isNotEmpty && !_uploading
                          ? _confirmDispatched
                          : null,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _uploading ? 'Uploading...' : 'Confirm & Mark Dispatched',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _images.isNotEmpty
                            ? const Color(0xFF10B981)
                            : AppColors.textTertiary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
          const SizedBox(width: 3),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductItemLog {
  final String name;
  final int qty;
  _ProductItemLog({required this.name, required this.qty});
}
