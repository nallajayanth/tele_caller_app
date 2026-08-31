import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/visit_model.dart';
import '../../../data/models/route_point_model.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'performance_score_screen.dart';

class EmployeeDailyReportScreen extends StatefulWidget {
  final String staffPhone;
  final String staffName;
  final String dateStr;

  const EmployeeDailyReportScreen({
    super.key,
    required this.staffPhone,
    required this.staffName,
    required this.dateStr,
  });

  @override
  State<EmployeeDailyReportScreen> createState() => _EmployeeDailyReportScreenState();
}

class _EmployeeDailyReportScreenState extends State<EmployeeDailyReportScreen> {
  bool _isLoading = true;
  AttendanceModel? _attendance;
  List<VisitModel> _visits = [];
  List<RoutePointModel> _routePoints = [];

  double _totalDistance = 0.0;
  Duration _travelTime = Duration.zero;
  Duration _idleTime = Duration.zero;
  Duration _workingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    try {
      final docId = '${widget.staffPhone}_${widget.dateStr}';

      // 1. Fetch attendance log
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(docId)
          .get();

      double firebaseTotalKm = 0.0;
      if (attendanceDoc.exists) {
        final data = attendanceDoc.data();
        if (data != null) {
          firebaseTotalKm = (data['total_km'] as num?)?.toDouble() ?? 0.0;
          _attendance = AttendanceModel.fromJson(data);
        }
      }

      // 2. Fetch route points
      final routeSnap = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(docId)
          .collection('route_points')
          .orderBy('timestamp', descending: false)
          .get();

      _routePoints = routeSnap.docs.map((doc) => RoutePointModel.fromJson(doc.data())).toList();

      // 3. Fetch visits
      final visitSnap = await FirebaseFirestore.instance
          .collection('customer_visits')
          .where('staff_phone', isEqualTo: widget.staffPhone)
          .get();

      _visits = [];
      for (final doc in visitSnap.docs) {
        final visit = VisitModel.fromJson(doc.data());
        final timeStr = visit.arrivalTime.toIso8601String();
        if (timeStr.startsWith(widget.dateStr)) {
          _visits.add(visit);
        }
      }
      _visits.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

      // 4. Calculate stats
      double calculatedDistance = 0.0;
      Duration calculatedTravelTime = Duration.zero;
      Duration calculatedIdleTime = Duration.zero;

      for (int i = 0; i < _routePoints.length - 1; i++) {
        final p1 = _routePoints[i];
        final p2 = _routePoints[i + 1];
        final dt = p2.timestamp.difference(p1.timestamp);

        if (dt.inSeconds <= 0 || dt.inHours > 6) continue;

        final dist = Geolocator.distanceBetween(
          p1.latitude,
          p1.longitude,
          p2.latitude,
          p2.longitude,
        );
        calculatedDistance += dist / 1000.0;

        final speed = dist / dt.inSeconds;
        if (speed > 0.5 && dist > 10.0) {
          calculatedTravelTime += dt;
        } else {
          calculatedIdleTime += dt;
        }
      }

      if (_attendance != null) {
        _workingTime = (_attendance!.endTime ?? DateTime.now()).difference(_attendance!.startTime);
      }

      setState(() {
        _totalDistance = firebaseTotalKm > 0.0 ? firebaseTotalKm : calculatedDistance;
        _travelTime = calculatedTravelTime;
        _idleTime = calculatedIdleTime;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching report data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    if (mins <= 0) return '0m';
    if (mins < 60) return '${mins}m';
    final hrs = mins ~/ 60;
    final remainingMins = mins % 60;
    return remainingMins > 0 ? '${hrs}h ${remainingMins}m' : '${hrs}h';
  }

  Future<void> _exportToCsv() async {
    try {
      final header = ['Parameter', 'Value'];
      final dateRow = ['Report Date', widget.dateStr];
      final staffRow = ['Employee Name', widget.staffName];
      final phoneRow = ['Phone Number', widget.staffPhone];
      final startRow = ['Duty Start', _attendance != null ? DateFormat('hh:mm a').format(_attendance!.startTime) : 'N/A'];
      final endRow = ['Duty End', _attendance != null && _attendance!.endTime != null ? DateFormat('hh:mm a').format(_attendance!.endTime!) : 'N/A'];
      final distanceRow = ['Distance Traveled', '${_totalDistance.toStringAsFixed(2)} KM'];
      final workTimeRow = ['Working Hours', _formatDuration(_workingTime)];
      final travelTimeRow = ['Travel Time', _formatDuration(_travelTime)];
      final idleTimeRow = ['Idle Time', _formatDuration(_idleTime)];
      final visitsCountRow = ['Total Visits', '${_visits.length}'];

      final List<List<String>> csvData = [
        header,
        dateRow,
        staffRow,
        phoneRow,
        startRow,
        endRow,
        distanceRow,
        workTimeRow,
        travelTimeRow,
        idleTimeRow,
        visitsCountRow,
      ];

      // Add visits list header
      csvData.add([]);
      csvData.add(['Stop No.', 'Customer Name', 'Type', 'Arrival', 'Departure', 'Duration', 'GPS Match', 'Photo Proof', 'Address']);
      for (int i = 0; i < _visits.length; i++) {
        final v = _visits[i];
        csvData.add([
          '${i + 1}',
          v.customerName,
          v.customerType,
          DateFormat('hh:mm a').format(v.arrivalTime),
          v.departureTime != null ? DateFormat('hh:mm a').format(v.departureTime!) : 'N/A',
          '${v.visitDurationMinutes} mins',
          v.isLocationMismatch ? 'Mismatch (>100m)' : 'Matched (<100m)',
          v.photoUrl != null && v.photoUrl!.isNotEmpty ? 'Uploaded' : 'Missing',
          v.address,
        ]);
      }

      final csvContent = const ListToCsvConverter().convert(csvData);

      final outputDir = await getTemporaryDirectory();
      final file = File('${outputDir.path}/Report_${widget.staffName}_${widget.dateStr}.csv');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Daily Report CSV for ${widget.staffName} (${widget.dateStr})',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final pdf = pw.Document();
      final primaryColor = PdfColor.fromHex('#006A4E');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Text(
              'EMPLOYEE DAILY PERFORMANCE REPORT',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: primaryColor, thickness: 1.5),
            pw.SizedBox(height: 12),

            // Meta Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Employee: ${widget.staffName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('Phone: ${widget.staffPhone}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: ${widget.dateStr}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Travel Summary stats
            pw.Text('DAILY MOVEMENT SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Distance Traveled', 'Working Hours', 'Travel Time', 'Idle Time', 'Total Visits'],
              data: [
                [
                  '${_totalDistance.toStringAsFixed(1)} KM',
                  _formatDuration(_workingTime),
                  _formatDuration(_travelTime),
                  _formatDuration(_idleTime),
                  '${_visits.length}',
                ]
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: primaryColor, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                left: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                right: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
            ),
            pw.SizedBox(height: 20),

            // Visits List table
            pw.Text('CUSTOMER VISITS BREAKDOWN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['No.', 'Customer Name', 'Type', 'Arrival / Departure', 'Duration', 'GPS Match', 'Photo Proof'],
              data: _visits.map((v) {
                final idx = _visits.indexOf(v) + 1;
                final arrStr = DateFormat('hh:mm a').format(v.arrivalTime);
                final depStr = v.departureTime != null ? DateFormat('hh:mm a').format(v.departureTime!) : 'N/A';
                return [
                  '$idx',
                  v.customerName,
                  v.customerType,
                  '$arrStr - $depStr',
                  '${v.visitDurationMinutes} mins',
                  v.isLocationMismatch ? 'Mismatch (>100m)' : 'Match (<100m)',
                  v.photoUrl != null && v.photoUrl!.isNotEmpty ? 'Uploaded ✓' : 'Missing ✗',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
              headerDecoration: pw.BoxDecoration(color: primaryColor, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              columnWidths: {
                0: const pw.FixedColumnWidth(25),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FlexColumnWidth(2.5),
                4: const pw.FixedColumnWidth(55),
                5: const pw.FixedColumnWidth(65),
                6: const pw.FixedColumnWidth(60),
              },
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
              },
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
            ),
          ],
        ),
      );

      final outputDir = await getTemporaryDirectory();
      final file = File('${outputDir.path}/Report_${widget.staffName}_${widget.dateStr}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Daily Report PDF for ${widget.staffName} (${widget.dateStr})',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daily Performance Report',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Performance Scorecard',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: _isLoading
                ? null
                : () {
                    final photoCount = _visits.where((v) => v.photoUrl != null && v.photoUrl!.isNotEmpty).length;
                    final mismatchCount = _visits.where((v) => v.isLocationMismatch).length;
                    final avgVisitDuration = _visits.isEmpty
                        ? 0.0
                        : (_visits.map((v) => v.visitDurationMinutes).reduce((a, b) => a + b) / _visits.length);

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PerformanceScoreScreen(
                          staffName: widget.staffName,
                          totalKm: _totalDistance,
                          totalVisits: _visits.length,
                          photoCount: photoCount,
                          mismatchCount: mismatchCount,
                          dutyStartTime: _attendance?.startTime,
                          totalWorkingMinutes: _workingTime.inMinutes,
                          totalIdleMinutes: _idleTime.inMinutes,
                          avgVisitDurationMinutes: avgVisitDuration,
                        ),
                      ),
                    );
                  },
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_rows_rounded),
            onPressed: _isLoading ? null : _exportToCsv,
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _isLoading ? null : _exportToPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Employee Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          widget.staffName.isNotEmpty ? widget.staffName[0].toUpperCase() : 'S',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.staffName,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Phone: ${widget.staffPhone}  •  Date: ${widget.dateStr}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Metrics Analytics Grid
                Text(
                  'Daily Movement Summary',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildReportCard('Distance', '${_totalDistance.toStringAsFixed(1)} KM', Icons.directions_walk_rounded, AppColors.primary, isDark),
                    const SizedBox(width: 8),
                    _buildReportCard('Working Hours', _formatDuration(_workingTime), Icons.work_rounded, AppColors.accent, isDark),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildReportCard('Travel Time', _formatDuration(_travelTime), Icons.drive_eta_rounded, AppColors.success, isDark),
                    const SizedBox(width: 8),
                    _buildReportCard('Idle Time', _formatDuration(_idleTime), Icons.bedtime_rounded, Colors.orange, isDark),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Attendance Timings Card
                Text(
                  'Duty Timings & Diagnostics',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildTimingRow('Duty Started', _attendance != null ? DateFormat('hh:mm a').format(_attendance!.startTime) : 'N/A', Icons.play_arrow_rounded, AppColors.success),
                      const Divider(height: 20),
                      _buildTimingRow('Duty Ended', _attendance != null && _attendance!.endTime != null ? DateFormat('hh:mm a').format(_attendance!.endTime!) : 'Active (In Progress)', Icons.stop_rounded, AppColors.error),
                      const Divider(height: 20),
                      _buildTimingRow('Duty Devices', 'Battery: ${_attendance?.startBattery}% ${_attendance?.endBattery != null ? "→ ${_attendance?.endBattery}%" : ""}', Icons.battery_charging_full_rounded, Colors.teal),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Shop / Doctor Visits Breakdown
                Text(
                  'Shop / Doctor Visits (${_visits.length} Logs)',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 10),
                if (_visits.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    alignment: Alignment.center,
                    child: Text('No visits logged on this day.', style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13)),
                  )
                else
                  ..._visits.map((v) => _buildVisitReportCard(v, isDark)),
              ],
            ),
    );
  }

  Widget _buildReportCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildVisitReportCard(VisitModel visit, bool isDark) {
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final isMismatch = visit.isLocationMismatch;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    visit.customerName,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    visit.customerType,
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              visit.address,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Divider(height: 10),
            const SizedBox(height: 8),

            // Timing metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arrival', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textTertiary)),
                    Text(DateFormat('hh:mm a').format(visit.arrivalTime), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Departure', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textTertiary)),
                    Text(visit.departureTime != null ? DateFormat('hh:mm a').format(visit.departureTime!) : 'N/A', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duration', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textTertiary)),
                    Text('${visit.visitDurationMinutes} mins', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Verification diagnostics
            Row(
              children: [
                Icon(
                  isMismatch ? Icons.cancel_rounded : Icons.check_circle_rounded,
                  size: 14,
                  color: isMismatch ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isMismatch ? 'Location Mismatch (> 100 meters)' : 'GPS Verification Match (< 100m)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: isMismatch ? AppColors.error : AppColors.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  visit.photoUrl != null && visit.photoUrl!.isNotEmpty ? Icons.photo_camera_rounded : Icons.no_photography_rounded,
                  size: 14,
                  color: visit.photoUrl != null && visit.photoUrl!.isNotEmpty ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    visit.photoUrl != null && visit.photoUrl!.isNotEmpty ? 'Photo Proof Verified' : 'Missing Photo Proof',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: visit.photoUrl != null && visit.photoUrl!.isNotEmpty ? AppColors.success : AppColors.error),
                  ),
                ),
              ],
            ),

            if (visit.photoUrl != null && visit.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showPhotoDialog(visit.photoUrl!, visit.customerName),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildVisitProofImage(visit.photoUrl!, width: 100, height: 75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisitProofImage(String url, {double? width, double? height}) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoErrorPlaceholder(width, height),
      );
    } else if (url.startsWith('/') || url.contains(':\\') || url.startsWith('file://')) {
      final cleanPath = url.startsWith('file://') ? url.substring(7) : url;
      return Image.file(
        File(cleanPath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoErrorPlaceholder(width, height),
      );
    } else if (url.startsWith('data:image') || url.length > 100) {
      try {
        final cleanBase64 = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoErrorPlaceholder(width, height),
        );
      } catch (_) {
        return _photoErrorPlaceholder(width, height);
      }
    }
    return _photoErrorPlaceholder(width, height);
  }

  Widget _photoErrorPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.15),
      child: const Icon(Icons.image_not_supported_rounded, color: AppColors.textTertiary, size: 20),
    );
  }

  void _showPhotoDialog(String photoUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Photo Proof — $title',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildVisitProofImage(photoUrl, width: double.infinity, height: 320),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
