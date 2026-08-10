import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../data/models/call_log_model.dart';
import '../../providers/order_providers.dart';

class PdfAnalyticsExporter {
  static Future<void> exportAnalyticsPdf({
    required String staffName,
    required bool isDaily,
    required String periodTitle,
    required double target,
    required double achieved,
    required double remaining,
    required double percent,
    required DailyOrderStats dailyStats,
    required List<CallLogModel> logs,
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#006A4E');
    final accentColor = PdfColor.fromHex('#F59E0B');
    final darkColor = PdfColor.fromHex('#1E293B');
    final lightBg = PdfColor.fromHex('#F8FAFC');

    final fmtCurr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MEDTRAC PRO TELECALLER',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        periodTitle,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: darkColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Staff: $staffName',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: darkColor,
                        ),
                      ),
                      pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: primaryColor, thickness: 1.5),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
        build: (pw.Context context) => [
          // ── Analytics Summary Box ────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfStat('TARGET', fmtCurr.format(target), primaryColor),
                _buildPdfStat('ACHIEVED', fmtCurr.format(achieved), PdfColor.fromHex('#10B981')),
                _buildPdfStat(
                  'REMAINING',
                  remaining > 0 ? fmtCurr.format(remaining) : 'Achieved ✓',
                  remaining > 0 ? accentColor : PdfColor.fromHex('#10B981'),
                ),
                _buildPdfStat('PROGRESS', '${(percent * 100).toStringAsFixed(0)}%', primaryColor),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Pipeline Summary (Daily view) ────────────────────────────
          if (isDaily) ...[
            pw.Text(
              'ORDER PIPELINE SUMMARY',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                _buildPipelineBadge('New Today', dailyStats.newOrdersToday.toString(), PdfColor.fromHex('#3B82F6')),
                pw.SizedBox(width: 8),
                _buildPipelineBadge('Pending', dailyStats.pendingDispatch.toString(), PdfColor.fromHex('#F59E0B')),
                pw.SizedBox(width: 8),
                _buildPipelineBadge('Packed', dailyStats.packedToday.toString(), PdfColor.fromHex('#8B5CF6')),
                pw.SizedBox(width: 8),
                _buildPipelineBadge('Dispatched', dailyStats.dispatchedToday.toString(), PdfColor.fromHex('#10B981')),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Call Logs Table ──────────────────────────────────────────
          pw.Text(
            'LOGS BREAKDOWN (${logs.length} LOGS)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),

          if (logs.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 20),
              child: pw.Center(
                child: pw.Text(
                  'No order activity logged for this period.',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Customer Name', 'Phone', 'Status', 'Product / Items', 'Amount'],
              data: logs.map((l) {
                return [
                  l.customerName,
                  l.mobile,
                  l.connectedStatus,
                  _formatProductString(l.product),
                  l.orderValue > 0 ? fmtCurr.format(l.orderValue) : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: pw.BoxDecoration(color: PdfColors.grey100),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            ),
        ],
      ),
    );

    // Save PDF file
    final outputDir = await getTemporaryDirectory();
    final fileName = '${isDaily ? "Daily" : "Monthly"}_Analytics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    // Share / Open PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$periodTitle PDF Report for $staffName',
      subject: periodTitle,
    );
  }

  static pw.Widget _buildPdfStat(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  static pw.Widget _buildPipelineBadge(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: color),
        ),
        child: pw.Column(
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
          ],
        ),
      ),
    );
  }

  static String _formatProductString(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = decoded.map((e) {
          if (e is Map) {
            final name = (e['product_name'] ?? e['name'] ?? 'Product').toString();
            final qty = e['qty'] ?? e['quantity'] ?? 1;
            return '$name (x$qty)';
          }
          return e.toString();
        }).toList();
        return items.join(', ');
      } else if (decoded is Map) {
        final name = (decoded['product_name'] ?? decoded['name'] ?? 'Product').toString();
        final qty = decoded['qty'] ?? decoded['quantity'] ?? 1;
        return '$name (x$qty)';
      }
    } catch (_) {}
    return raw;
  }
}
