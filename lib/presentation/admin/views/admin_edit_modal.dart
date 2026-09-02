import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/product_formatter.dart';
import '../../../data/models/call_log_model.dart';
import '../../../data/models/product_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/product_providers.dart';
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
  late final TextEditingController _productSearchCtrl;

  late String? _selectedStatus;
  late DateTime _followUpDate;
  bool _isSaving = false;

  final Map<String, int> _selectedProductQuantities = {};
  final Map<String, double> _selectedProductPrices = {};
  final Map<String, TextEditingController> _priceCtrls = {};
  final Map<String, TextEditingController> _qtyCtrls = {};
  String _productSearchQuery = '';

  String _formatProductText(String product) {
    try {
      final list = jsonDecode(product) as List;
      if (list.isEmpty) return '';
      final formattedItems = list.map((item) {
        final name = item['name'] as String? ?? '';
        final qty = item['qty'] ?? 1;
        return '$name × $qty';
      }).toList();
      return formattedItems.join(', ');
    } catch (_) {
      return product;
    }
  }

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _nameCtrl = TextEditingController(text: log.customerName);
    _mobileCtrl = TextEditingController(text: log.mobile);
    _placeCtrl = TextEditingController(text: log.place);
    _productCtrl = TextEditingController(text: _formatProductText(log.product));
    _responseCtrl = TextEditingController(text: log.customerResponse);
    _remarksCtrl = TextEditingController(text: log.remarks);
    _orderCtrl =
        TextEditingController(text: log.orderValue.toStringAsFixed(0));
    _selectedStatus =
        log.connectedStatus.isEmpty ? null : log.connectedStatus;
    _followUpDate = log.nextFollowUpDate;
    _productSearchCtrl = TextEditingController();
    _productSearchCtrl.addListener(() {
      setState(() {
        _productSearchQuery = _productSearchCtrl.text;
      });
    });
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
    _productSearchCtrl.dispose();
    for (final ctrl in _priceCtrls.values) {
      ctrl.dispose();
    }
    for (final ctrl in _qtyCtrls.values) {
      ctrl.dispose();
    }
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

    if (_selectedStatus == 'Order Received' && _selectedProductQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product with quantity > 0!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    String savedProductStr;
    if (_selectedProductQuantities.isNotEmpty) {
      final products = ref.read(productsProvider).valueOrNull ?? [];
      final List<Map<String, dynamic>> selectedItems = [];
      _selectedProductQuantities.forEach((prodId, qty) {
        final p = products.firstWhere(
          (prod) => prod.id == prodId || prod.name.trim().toLowerCase() == prodId.trim().toLowerCase(),
          orElse: () => ProductModel(id: prodId, name: prodId, price: 0.0, stock: 0),
        );
        final name = (p.name != 'Unknown' && p.name.isNotEmpty) ? p.name : prodId;
        final price = _selectedProductPrices[prodId] ?? p.price;
        selectedItems.add({
          'id': p.id,
          'name': name,
          'price': price,
          'qty': qty,
        });
      });
      savedProductStr = jsonEncode(selectedItems);
    } else {
      savedProductStr = _productCtrl.text.trim();
    }

    final updated = widget.log.copyWith(
      customerName: _nameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      place: _placeCtrl.text.trim(),
      product: savedProductStr,
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

  bool _productsInitialized = false;

  void _initProductsIfNeeded(List<ProductModel> products) {
    if (_productsInitialized) return;
    if (products.isEmpty && widget.log.product.isNotEmpty) return;

    final log = widget.log;
    if (log.product.isEmpty) {
      _productsInitialized = true;
      return;
    }

    _selectedProductQuantities.clear();
    _selectedProductPrices.clear();
    _priceCtrls.clear();

    final raw = log.product.trim();

    if (raw.startsWith('[') || raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        List itemsList = [];
        if (decoded is List) {
          itemsList = decoded;
        } else if (decoded is Map) {
          itemsList = [decoded];
        }

        for (var item in itemsList) {
          if (item is Map) {
            final idStr = item['id']?.toString().trim() ?? '';
            final nameStr = (item['name'] ?? item['product_name'] ?? '').toString().trim();
            final qtyVal = item['qty'] ?? item['quantity'];
            final priceVal = item['price'];
            final qty = qtyVal is num ? qtyVal.toInt() : (int.tryParse(qtyVal?.toString() ?? '') ?? 1);
            final price = priceVal is num ? priceVal.toDouble() : (double.tryParse(priceVal?.toString() ?? '') ?? 0.0);

            if (qty > 0) {
              ProductModel? matchedProduct;
              if (idStr.isNotEmpty) {
                matchedProduct = products.where((p) => p.id == idStr).firstOrNull;
              }
              if (matchedProduct == null && nameStr.isNotEmpty) {
                matchedProduct = products.where((p) => p.name.trim().toLowerCase() == nameStr.toLowerCase()).firstOrNull;
              }

              final key = matchedProduct?.id ?? (idStr.isNotEmpty ? idStr : nameStr);
              final itemPrice = price > 0 ? price : (matchedProduct?.price ?? 0.0);

              if (key.isNotEmpty) {
                _selectedProductQuantities[key] = qty;
                _selectedProductPrices[key] = itemPrice;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error decoding product JSON in AdminEditModal: $e');
      }
    }

    if (_selectedProductQuantities.isEmpty) {
      final parts = raw.split(RegExp(r'[\r\n,]+'));
      for (final part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue;

        final match = RegExp(r'^(.+?)\s*[×x]\s*(\d+)$', caseSensitive: false).firstMatch(trimmedPart);
        String name = trimmedPart;
        int qty = 1;
        if (match != null) {
          name = match.group(1)!.trim();
          qty = int.tryParse(match.group(2)!) ?? 1;
        }

        final matchedProduct = products.where((p) => p.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;
        final key = matchedProduct?.id ?? name;
        if (key.isNotEmpty && qty > 0) {
          _selectedProductQuantities[key] = qty;
          _selectedProductPrices[key] = matchedProduct?.price ?? 0.0;
        }
      }
    }

    if (_selectedProductQuantities.isNotEmpty) {
      double totalProductPrice = 0;
      _selectedProductQuantities.forEach((key, qty) {
        totalProductPrice += (_selectedProductPrices[key] ?? 0.0) * qty;
      });
      if (totalProductPrice == 0 && log.orderValue > 0) {
        final totalQty = _selectedProductQuantities.values.fold<int>(0, (a, b) => a + b);
        if (totalQty > 0) {
          final avgPrice = log.orderValue / totalQty;
          for (final key in _selectedProductQuantities.keys) {
            _selectedProductPrices[key] = avgPrice;
          }
        }
      }
    }

    _productsInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = ref.watch(productsProvider).valueOrNull ?? [];

    _initProductsIfNeeded(products);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
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
                    _EditField(
                      ctrl: _placeCtrl,
                      label: 'Place / Market Area',
                      icon: Icons.location_on_rounded,
                      minLines: 2,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                    ),
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
                      onChanged: (s) => setState(() {
                        _selectedStatus = s;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _buildProductSelector(context, isDark, products, isDark ? AppColors.darkSurface : Colors.white),
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
    ),
  );
}

  Widget _buildStockBadge(int stock) {
    final isOk = stock > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOk
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isOk ? 'Stock: $stock' : 'Out of stock',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isOk ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }

  TextEditingController _priceCtrlFor(String prodId, double initialPrice) {
    return _priceCtrls.putIfAbsent(
      prodId,
      () => TextEditingController(text: initialPrice.toStringAsFixed(0)),
    );
  }

  TextEditingController _qtyCtrlFor(String prodId, int qty) {
    return _qtyCtrls.putIfAbsent(
      prodId,
      () => TextEditingController(text: qty > 0 ? '$qty' : ''),
    );
  }

  void _showAdminProductPicker(List<ProductModel> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return StatefulBuilder(
            builder: (context, setModalState) {
              final query = _productSearchQuery.trim().toLowerCase();
              final filteredList = products.where((p) => p.name.toLowerCase().contains(query)).toList();

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Products & Set Price',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${products.length} products available',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: TextField(
                        controller: _productSearchCtrl,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by product name...',
                          hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                          suffixIcon: _productSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textTertiary),
                                  onPressed: () {
                                    _productSearchCtrl.clear();
                                    setModalState(() {
                                      _productSearchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.border.withValues(alpha: 0.4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            _productSearchQuery = val;
                          });
                        },
                      ),
                    ),

                    // List
                    Expanded(
                      child: filteredList.isEmpty
                          ? Center(
                              child: Text(
                                'No products match your search',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textTertiary),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredList.length,
                              itemBuilder: (context, i) {
                                final p = filteredList[i];
                                final qty = _selectedProductQuantities[p.id] ?? 0;
                                final isSelected = qty > 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.07)
                                        : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.03)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.2)
                                        : Border.all(color: isDark ? AppColors.borderDark : AppColors.border, width: 0.8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p.name,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                      color: isSelected
                                                          ? AppColors.primary
                                                          : (isDark ? Colors.white : AppColors.textPrimary),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      _buildStockBadge(p.stock),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Price: ₹${p.price.toStringAsFixed(0)}',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppColors.textTertiary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isSelected) ...[
                                                  _QtyButton(
                                                    icon: Icons.remove_rounded,
                                                    onTap: () {
                                                      setModalState(() {
                                                        final newQty = qty - 1;
                                                        if (newQty <= 0) {
                                                          _selectedProductQuantities.remove(p.id);
                                                          _qtyCtrls[p.id]?.clear();
                                                        } else {
                                                          _selectedProductQuantities[p.id] = newQty;
                                                          _qtyCtrlFor(p.id, newQty).text = '$newQty';
                                                        }
                                                        _recalculateOrderFromProducts(products);
                                                      });
                                                      setState(() {});
                                                    },
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
                                                      controller: _qtyCtrlFor(p.id, qty),
                                                      keyboardType: TextInputType.number,
                                                      textAlign: TextAlign.center,
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
                                                      onChanged: (val) {
                                                        final newQty = int.tryParse(val) ?? 0;
                                                        setModalState(() {
                                                          if (newQty <= 0) {
                                                            _selectedProductQuantities.remove(p.id);
                                                          } else {
                                                            _selectedProductQuantities[p.id] = newQty;
                                                            if (!_selectedProductPrices.containsKey(p.id)) {
                                                              _selectedProductPrices[p.id] = p.price;
                                                            }
                                                          }
                                                          _recalculateOrderFromProducts(products);
                                                        });
                                                        setState(() {});
                                                      },
                                                    ),
                                                  ),
                                                ],
                                                _QtyButton(
                                                  icon: Icons.add_rounded,
                                                  onTap: () {
                                                    setModalState(() {
                                                      final newQty = qty + 1;
                                                      _selectedProductQuantities[p.id] = newQty;
                                                      if (!_selectedProductPrices.containsKey(p.id)) {
                                                        _selectedProductPrices[p.id] = p.price;
                                                      }
                                                      _qtyCtrlFor(p.id, newQty).text = '$newQty';
                                                      _recalculateOrderFromProducts(products);
                                                    });
                                                    setState(() {});
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (isSelected) ...[
                                          const Divider(height: 16),
                                          Row(
                                            children: [
                                              const Icon(Icons.currency_rupee_rounded, size: 14, color: AppColors.accent),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: SizedBox(
                                                  height: 36,
                                                  child: TextField(
                                                    controller: _priceCtrlFor(p.id, _selectedProductPrices[p.id] ?? p.price),
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                                    ],
                                                    onChanged: (v) {
                                                      final price = double.tryParse(v) ?? 0.0;
                                                      setModalState(() {
                                                        _selectedProductPrices[p.id] = price;
                                                        _recalculateOrderFromProducts(products);
                                                      });
                                                      setState(() {});
                                                    },
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.accent,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: 'Enter price',
                                                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textTertiary),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      filled: true,
                                                      fillColor: AppColors.accent.withValues(alpha: 0.06),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Subtotal: ₹${(qty * (_selectedProductPrices[p.id] ?? p.price)).toStringAsFixed(0)}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
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

                    // Confirm Selection Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Confirm Selection',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProductSelector(BuildContext context, bool isDark, List<ProductModel> products, Color cardColor) {
    final selectedCount = _selectedProductQuantities.values.fold<int>(0, (sum, val) => sum + val);

    String displayText = 'Search & select products...';
    if (selectedCount > 0) {
      final formattedText = ProductFormatter.format(_productCtrl.text);
      if (_selectedStatus == 'Order Received') {
        displayText = '$selectedCount product(s) selected (₹${_orderCtrl.text})';
      } else {
        displayText = formattedText.isNotEmpty ? formattedText : '$selectedCount product(s) selected';
      }
    } else if (_productCtrl.text.isNotEmpty) {
      displayText = ProductFormatter.format(_productCtrl.text);
    }

    final hasProducts = selectedCount > 0 || _productCtrl.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedStatus == 'Order Received' ? 'Products & Quantities *' : 'Products & Quantities',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showAdminProductPicker(products),
          child: Container(
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
                    displayText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasProducts ? AppColors.primary : AppColors.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _recalculateOrderFromProducts(List<ProductModel> products) {
    try {
      double total = 0;
      final List<Map<String, dynamic>> selectedItems = [];

      _selectedProductQuantities.forEach((prodId, qty) {
        final p = products.firstWhere(
          (prod) => prod.id == prodId || prod.name.trim().toLowerCase() == prodId.trim().toLowerCase(),
          orElse: () => ProductModel(id: prodId, name: prodId, price: 0.0, stock: 0),
        );
        final name = (p.name != 'Unknown' && p.name.isNotEmpty) ? p.name : prodId;
        final price = _selectedProductPrices[prodId] ?? p.price;
        total += price * qty;
        selectedItems.add({
          'id': p.id,
          'name': name,
          'price': price,
          'qty': qty,
        });
      });

      _orderCtrl.text = total.toStringAsFixed(0);
      _productCtrl.text = selectedItems.isEmpty
          ? ''
          : selectedItems.map((e) => '${e['name']} × ${e['qty']}').join(', ');
    } catch (e, stack) {
      debugPrint('Error recalculating order value: $e\n$stack');
    }
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int? maxLines;
  final int? minLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: minLines,
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

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isEnabled ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }
}
