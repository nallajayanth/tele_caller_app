import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/visit_model.dart';
import 'user_management_screen.dart';
import 'employee_daily_report_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String _selectedEmployeePhone = 'All';
  DateTimeRange? _selectedDateRange;
  String _selectedCustomerType = 'All';
  final TextEditingController _locationSearchCtrl = TextEditingController();

  bool _isExporting = false;

  @override
  void dispose() {
    _locationSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose Date Filter Mode',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                title: Text('Single Day', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Filter logs for a specific day', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDateRange?.start ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            surface: Theme.of(context).cardColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _selectedDateRange = DateTimeRange(
                        start: DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 0, 0),
                        end: DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 23, 59, 59),
                      );
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range_rounded, color: AppColors.accent),
                title: Text('Date Range', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Filter logs between start and end dates', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final pickedRange = await showDateRangePicker(
                    context: context,
                    initialDateRange: _selectedDateRange,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            surface: Theme.of(context).cardColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedRange != null) {
                    setState(() {
                      _selectedDateRange = pickedRange;
                    });
                  }
                },
              ),
              if (_selectedDateRange != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.clear_rounded, color: AppColors.error),
                  title: Text('Clear Date Filter', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                  subtitle: Text('Show logs for all dates', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _selectedDateRange = null;
                    });
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedEmployeePhone = 'All';
      _selectedDateRange = null;
      _selectedCustomerType = 'All';
      _locationSearchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports & Analytics',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Filters',
            icon: const Icon(Icons.filter_alt_off_rounded),
            onPressed: _clearFilters,
          ),
        ],
      ),
      body: employeesAsync.when(
        data: (employees) {
          final staffMembers = employees.where((e) => e.isFieldStaff).toList();

          return Column(
            children: [
              // ── FILTERS PANEL ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border(
                    bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                  ),
                ),
                child: Column(
                  children: [
                    // Row 1: Employee Dropdown & Period Selector
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedEmployeePhone,
                            decoration: const InputDecoration(
                              labelText: 'Employee',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem(value: 'All', child: Text('All Employees')),
                              ...staffMembers.map((s) => DropdownMenuItem(value: s.phoneNumber, child: Text(s.name))),
                            ],
                            onChanged: (val) => setState(() => _selectedEmployeePhone = val ?? 'All'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDateRange(context),
                            icon: const Icon(Icons.date_range_rounded, size: 16),
                            label: Text(
                              _selectedDateRange == null
                                  ? 'All Dates'
                                  : _selectedDateRange!.start.year == _selectedDateRange!.end.year &&
                                          _selectedDateRange!.start.month == _selectedDateRange!.end.month &&
                                          _selectedDateRange!.start.day == _selectedDateRange!.end.day
                                      ? DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)
                                      : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row 2: Customer Type Dropdown & Area/City search input
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCustomerType,
                            decoration: const InputDecoration(
                              labelText: 'Customer Type',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Types')),
                              DropdownMenuItem(value: 'Doctor', child: Text('Doctor')),
                              DropdownMenuItem(value: 'Distributor', child: Text('Distributor')),
                              DropdownMenuItem(value: 'Medical Shop', child: Text('Medical Shop')),
                            ],
                            onChanged: (val) => setState(() => _selectedCustomerType = val ?? 'All'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _locationSearchCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Area / City / State',
                              hintText: 'Search location...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 16),
                              suffixIcon: _locationSearchCtrl.text.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear, size: 14), onPressed: () => setState(() => _locationSearchCtrl.clear()))
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── EXPORT ACTIONS BAR ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtered Reports',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textTertiary),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _isExporting ? null : () => _exportFilteredData(isPdf: false),
                          icon: const Icon(Icons.table_rows_rounded, size: 16),
                          label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: _isExporting ? null : () => _exportFilteredData(isPdf: true),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── REPORTS LIST ───────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('attendance_logs').snapshots(),
                  builder: (context, attendanceSnap) {
                    if (attendanceSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final attendanceDocs = attendanceSnap.data?.docs ?? [];
                    final attendanceLogs = attendanceDocs.map((doc) => AttendanceModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('customer_visits').snapshots(),
                      builder: (context, visitSnap) {
                        if (visitSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final visitDocs = visitSnap.data?.docs ?? [];
                        final visits = visitDocs.map((doc) => VisitModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

                        // ── FILTER IMPLEMENTATION ────────────────────────────
                        final List<_ReportRow> reportsList = [];

                        for (final att in attendanceLogs) {
                          // Filter by employee
                          if (_selectedEmployeePhone != 'All' && att.staffPhone != _selectedEmployeePhone) continue;

                          // Filter by date range
                          if (_selectedDateRange != null) {
                            final attDate = att.startTime;
                            if (attDate.isBefore(_selectedDateRange!.start) || attDate.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
                              continue;
                            }
                          }

                          // Find visits for this staff and date
                          final dayVisits = visits.where((v) {
                            final sameStaff = v.staffPhone == att.staffPhone;
                            final sameDate = v.arrivalTime.toIso8601String().startsWith(att.date);
                            return sameStaff && sameDate;
                          }).toList();

                          // Filter by customer type
                          if (_selectedCustomerType != 'All') {
                            final hasType = dayVisits.any((v) => v.customerType == _selectedCustomerType);
                            if (!hasType) continue;
                          }

                          // Filter by location query (Area / City / State)
                          if (_locationSearchCtrl.text.isNotEmpty) {
                            final query = _locationSearchCtrl.text.trim().toLowerCase();
                            final matchesLocation = dayVisits.any((v) => v.address.toLowerCase().contains(query));
                            if (!matchesLocation) continue;
                          }

                          reportsList.add(_ReportRow(
                            attendance: att,
                            visits: dayVisits,
                          ));
                        }

                        // Sort chronologically (newest reports first)
                        reportsList.sort((a, b) => b.attendance.startTime.compareTo(a.attendance.startTime));

                        if (reportsList.isEmpty) {
                          return Center(
                            child: Text(
                              'No reports match your filters.',
                              style: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary, fontSize: 13),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: reportsList.length,
                          itemBuilder: (ctx, idx) {
                            final row = reportsList[idx];
                            final startStr = DateFormat('hh:mm a').format(row.attendance.startTime);
                            final endStr = row.attendance.endTime != null ? DateFormat('hh:mm a').format(row.attendance.endTime!) : 'Active';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.assignment_rounded, color: AppColors.primary),
                                ),
                                title: Text(
                                  row.attendance.staffName,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Date: ${row.attendance.date}  •  $startStr - $endStr\nVisits: ${row.visits.length}  •  Distance: ${row.attendance.totalWorkingMinutes > 0 ? "" : ""}',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textTertiary, height: 1.4),
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EmployeeDailyReportScreen(
                                      staffPhone: row.attendance.staffPhone,
                                      staffName: row.attendance.staffName,
                                      dateStr: row.attendance.date,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading staff: $err')),
      ),
    );
  }

  Future<void> _exportFilteredData({required bool isPdf}) async {
    setState(() => _isExporting = true);
    
    try {
      // 1. Fetch raw datasets matching the filters
      final attendanceSnap = await FirebaseFirestore.instance.collection('attendance_logs').get();
      final visitSnap = await FirebaseFirestore.instance.collection('customer_visits').get();

      final attendanceLogs = attendanceSnap.docs.map((doc) => AttendanceModel.fromJson(doc.data())).toList();
      final visits = visitSnap.docs.map((doc) => VisitModel.fromJson(doc.data())).toList();

      final List<_ReportRow> filteredList = [];
      for (final att in attendanceLogs) {
        if (_selectedEmployeePhone != 'All' && att.staffPhone != _selectedEmployeePhone) continue;
        if (_selectedDateRange != null) {
          final attDate = att.startTime;
          if (attDate.isBefore(_selectedDateRange!.start) || attDate.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
            continue;
          }
        }
        final dayVisits = visits.where((v) {
          return v.staffPhone == att.staffPhone && v.arrivalTime.toIso8601String().startsWith(att.date);
        }).toList();

        if (_selectedCustomerType != 'All' && !dayVisits.any((v) => v.customerType == _selectedCustomerType)) continue;
        if (_locationSearchCtrl.text.isNotEmpty) {
          final query = _locationSearchCtrl.text.trim().toLowerCase();
          if (!dayVisits.any((v) => v.address.toLowerCase().contains(query))) continue;
        }

        filteredList.add(_ReportRow(attendance: att, visits: dayVisits));
      }

      if (filteredList.isEmpty) {
        throw Exception('No data matches the selected filters to export.');
      }

      if (isPdf) {
        // ── GENERATE PDF REPORT ──────────────────────────────────────
        final pdf = pw.Document();
        final primaryColor = PdfColor.fromHex('#006A4E');

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) => [
              pw.Text('CONSOLIDATED STAFF ATTENDANCE & VISITS REPORT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 6),
              pw.Text('Filters: Employee: $_selectedEmployeePhone • Type: $_selectedCustomerType • Location Search: ${_locationSearchCtrl.text}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 12),
              pw.Divider(color: primaryColor, thickness: 1),
              pw.SizedBox(height: 12),

              pw.TableHelper.fromTextArray(
                headers: ['Employee', 'Date', 'Start Time', 'End Time', 'Visits Count'],
                data: filteredList.map((row) {
                  return [
                    row.attendance.staffName,
                    row.attendance.date,
                    DateFormat('hh:mm a').format(row.attendance.startTime),
                    row.attendance.endTime != null ? DateFormat('hh:mm a').format(row.attendance.endTime!) : 'Active',
                    '${row.visits.length}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: pw.BoxDecoration(color: primaryColor, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(70),
                  2: const pw.FixedColumnWidth(75),
                  3: const pw.FixedColumnWidth(75),
                  4: const pw.FixedColumnWidth(70),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
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
        final file = File('${outputDir.path}/Consolidated_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
        await file.writeAsBytes(await pdf.save());

        await Share.shareXFiles([XFile(file.path)], text: 'Consolidated PDF Report');
      } else {
        // ── GENERATE CSV REPORT ──────────────────────────────────────
        final List<List<String>> csvRows = [
          ['Employee Name', 'Phone', 'Date', 'Start Time', 'End Time', 'Visits Count']
        ];

        for (final row in filteredList) {
          csvRows.add([
            row.attendance.staffName,
            row.attendance.staffPhone,
            row.attendance.date,
            DateFormat('hh:mm a').format(row.attendance.startTime),
            row.attendance.endTime != null ? DateFormat('hh:mm a').format(row.attendance.endTime!) : 'Active',
            '${row.visits.length}',
          ]);
        }

        final csvContent = const ListToCsvConverter().convert(csvRows);

        final outputDir = await getTemporaryDirectory();
        final file = File('${outputDir.path}/Consolidated_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
        await file.writeAsString(csvContent);

        await Share.shareXFiles([XFile(file.path)], text: 'Consolidated CSV Report');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      setState(() => _isExporting = false);
    }
  }
}

class _ReportRow {
  final AttendanceModel attendance;
  final List<VisitModel> visits;

  const _ReportRow({
    required this.attendance,
    required this.visits,
  });
}
