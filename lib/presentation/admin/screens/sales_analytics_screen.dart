import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/call_log_model.dart';
import '../../../data/models/product_model.dart';
import '../../../providers/call_log_providers.dart';
import '../../../providers/product_providers.dart';

class SalesAnalyticsScreen extends ConsumerStatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  ConsumerState<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends ConsumerState<SalesAnalyticsScreen> {
  double _profitMarginPercent = 35.0; // Default 35% margin

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    final logsAsync = ref.watch(callLogsProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Sales & Analytics', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: logsAsync.when(
        data: (logs) {
          // Filter logs where status is Order Received (actual sales)
          final salesLogs = logs.where((l) => l.connectedStatus == 'Order Received').toList();

          // Cumulative Sales
          final totalSales = salesLogs.fold<double>(0.0, (sum, l) => sum + l.orderValue);

          final now = DateTime.now();
          final todayLogs = salesLogs.where((l) =>
              l.date.year == now.year &&
              l.date.month == now.month &&
              l.date.day == now.day).toList();

          final thisMonthLogs = salesLogs.where((l) =>
              l.date.year == now.year &&
              l.date.month == now.month).toList();

          final monthlySalesValue = thisMonthLogs.fold<double>(0.0, (sum, l) => sum + l.orderValue);
          final dailyAvgSalesValue = now.day > 0 ? monthlySalesValue / now.day : 0.0;

          // Parse quantities sold
          final todaySold = _getProductQuantities(todayLogs, products);
          final thisMonthSold = _getProductQuantities(thisMonthLogs, products);

          final allProductNames = <String>{};
          for (final p in products) {
            allProductNames.add(p.name);
          }
          allProductNames.addAll(thisMonthSold.keys);

          final List<_ProductReportRow> productsReport = allProductNames.map((name) {
            final productObj = products.firstWhere(
              (p) => p.name == name,
              orElse: () => ProductModel(id: '', name: name, price: 0, stock: 0),
            );

            final qtyToday = todaySold[name] ?? 0;
            final qtyMonth = thisMonthSold[name] ?? 0;
            final stock = productObj.stock;

            // Restock prediction
            double avgPerDay = now.day > 0 ? qtyMonth / now.day : 0.0;
            int? daysRemaining;
            if (avgPerDay > 0) {
              daysRemaining = (stock / avgPerDay).round();
            }

            return _ProductReportRow(
              name: name,
              qtyToday: qtyToday,
              qtyMonth: qtyMonth,
              stock: stock,
              daysRemaining: daysRemaining,
              isConfigured: productObj.id.isNotEmpty,
            );
          }).toList();

          // Profit Margin
          final estimatedProfit = totalSales * (_profitMarginPercent / 100);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Dashboard overview cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'TOTAL SALES',
                      '₹${_formatCurrency(totalSales)}',
                      Icons.payments_rounded,
                      AppColors.primary,
                      cardColor,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'THIS MONTH',
                      '₹${_formatCurrency(monthlySalesValue)}',
                      Icons.calendar_month_rounded,
                      AppColors.accent,
                      cardColor,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Profit Margin Calculator Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFIT MARGIN ESTIMATOR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gross Sales:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textTertiary),
                        ),
                        Text(
                          '₹${_formatCurrency(totalSales)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Margin Percent:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textTertiary),
                        ),
                        Text(
                          '${_profitMarginPercent.toStringAsFixed(0)}%',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Slider(
                      value: _profitMarginPercent,
                      min: 10,
                      max: 80,
                      divisions: 14,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _profitMarginPercent = val),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated Net Profit:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '₹${_formatCurrency(estimatedProfit)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Product Breakdown & Predictions Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUCT VOLUMES & STOCK PREDICTIONS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Divider(height: 24),
                    if (productsReport.isEmpty)
                      Center(
                        child: Text(
                          'No sales recorded yet.',
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary),
                        ),
                      )
                    else
                      ...productsReport.map((p) => _buildProductReportItem(context, isDark, p)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Restocking Summary Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY AVERAGES SUMMARY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0x223B82F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Average Daily Sales Value',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '₹${_formatCurrency(dailyAvgSalesValue)} / day (this month)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error loading analytics: $e')),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Color bg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTertiary,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductReportItem(BuildContext context, bool isDark, _ProductReportRow p) {
    Color stockColor = AppColors.success;
    String stockText = 'Stock: ${p.stock}';
    
    if (p.stock <= 0) {
      stockColor = AppColors.error;
      stockText = 'Out of Stock';
    } else if (p.stock < 10) {
      stockColor = AppColors.warning;
      stockText = 'Low Stock: ${p.stock}';
    }

    Color predictionColor = AppColors.textTertiary;
    String predictionText = 'No sales data to predict restock';

    if (p.stock <= 0) {
      predictionColor = AppColors.error;
      predictionText = 'Restock immediately!';
    } else if (p.daysRemaining != null) {
      if (p.daysRemaining! <= 5) {
        predictionColor = AppColors.error;
        predictionText = 'Stock runs out in ${p.daysRemaining} days!';
      } else if (p.daysRemaining! <= 15) {
        predictionColor = AppColors.warning;
        predictionText = 'Stock runs out in ${p.daysRemaining} days';
      } else {
        predictionColor = AppColors.success;
        predictionText = '${p.daysRemaining} days of stock left';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stockText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: stockColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY',
                    style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.qtyToday} units',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'THIS MONTH',
                    style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.qtyMonth} units',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 12),
          Row(
            children: [
              Icon(
                p.stock <= 0 || (p.daysRemaining != null && p.daysRemaining! <= 5)
                    ? Icons.warning_amber_rounded
                    : Icons.query_builder_rounded,
                size: 14,
                color: predictionColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  predictionText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: predictionColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, int> _getProductQuantities(List<CallLogModel> salesLogs, List<ProductModel> products) {
    final Map<String, int> productSoldQuantities = {};

    for (final log in salesLogs) {
      final prodStr = log.product.trim();
      if (prodStr.isEmpty) continue;

      // Check if JSON
      if (prodStr.startsWith('[') && prodStr.endsWith(']')) {
        try {
          final decoded = jsonDecode(prodStr);
          if (decoded is List) {
            for (var item in decoded) {
              if (item is Map) {
                final id = item['id'] as String?;
                final qty = item['qty'] as int? ?? 0;
                final name = item['name'] as String?;

                // Find matching product by ID or Name
                final matchedProduct = products.firstWhere(
                  (p) => p.id == id || p.name == name,
                  orElse: () => ProductModel(id: id ?? name ?? '', name: name ?? 'Unknown', price: 0, stock: 0),
                );

                productSoldQuantities[matchedProduct.name] = (productSoldQuantities[matchedProduct.name] ?? 0) + qty;
              }
            }
          }
          continue;
        } catch (_) {}
      }

      // Fallback parsing for raw strings (e.g. "1-Drum x2, 4-Drum x1" or "1-Drum")
      final parts = prodStr.split(',');
      for (var part in parts) {
        part = part.trim();
        if (part.isEmpty) continue;

        final match = RegExp(r'(.+?)\s+x\s*(\d+)').firstMatch(part);
        if (match != null) {
          final name = match.group(1)!.trim();
          final qty = int.tryParse(match.group(2)!) ?? 1;

          final matchedProduct = products.firstWhere(
            (p) => p.name.toLowerCase() == name.toLowerCase() || p.id == name,
            orElse: () => ProductModel(id: name, name: name, price: 0, stock: 0),
          );
          productSoldQuantities[matchedProduct.name] = (productSoldQuantities[matchedProduct.name] ?? 0) + qty;
        } else {
          final name = part;
          final matchedProduct = products.firstWhere(
            (p) => p.name.toLowerCase() == name.toLowerCase() || p.id == name,
            orElse: () => ProductModel(id: name, name: name, price: 0, stock: 0),
          );
          productSoldQuantities[matchedProduct.name] = (productSoldQuantities[matchedProduct.name] ?? 0) + 1;
        }
      }
    }

    return productSoldQuantities;
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##,###').format(amount);
  }
}

class _ProductReportRow {
  final String name;
  final int qtyToday;
  final int qtyMonth;
  final int stock;
  final int? daysRemaining;
  final bool isConfigured;

  const _ProductReportRow({
    required this.name,
    required this.qtyToday,
    required this.qtyMonth,
    required this.stock,
    this.daysRemaining,
    required this.isConfigured,
  });
}
