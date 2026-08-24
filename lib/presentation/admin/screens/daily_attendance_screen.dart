import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/telecaller_model.dart';
import '../../../providers/attendance_providers.dart';
import 'user_management_screen.dart';

class DailyAttendanceScreen extends ConsumerStatefulWidget {
  const DailyAttendanceScreen({super.key});

  @override
  ConsumerState<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends ConsumerState<DailyAttendanceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'Active', 'Completed', 'Absent'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
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

    if (picked != null && picked != currentDate) {
      HapticFeedback.lightImpact();
      ref.read(adminAttendanceDateProvider.notifier).state = picked;
    }
  }

  void _showSelfieDialog(BuildContext context, String selfieUrl, String staffName) {
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
                  Text(
                    'Selfie — $staffName',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
                child: _buildSelfieImage(selfieUrl, width: double.infinity, height: 320, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelfieImage(String selfieUrl, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (selfieUrl.startsWith('http')) {
      return Image.network(
        selfieUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _selfieErrorPlaceholder(width, height),
      );
    } else if (selfieUrl.startsWith('data:image') || selfieUrl.length > 100) {
      try {
        final cleanBase64 = selfieUrl.contains(',') ? selfieUrl.split(',').last : selfieUrl;
        final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _selfieErrorPlaceholder(width, height),
        );
      } catch (_) {
        return _selfieErrorPlaceholder(width, height);
      }
    }
    return _selfieErrorPlaceholder(width, height);
  }

  Widget _selfieErrorPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.15),
      child: const Icon(Icons.person_rounded, color: AppColors.textTertiary, size: 28),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 mins';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    if (hrs == 0) return '$mins mins';
    return mins > 0 ? '$hrs hrs $mins mins' : '$hrs hrs';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    final selectedDate = ref.watch(adminAttendanceDateProvider);
    final dateDisplayStr = DateFormat('EEE, dd MMM yyyy').format(selectedDate);

    final employeesAsync = ref.watch(employeesProvider);
    final attendanceAsync = ref.watch(dailyAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daily Attendance',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(employeesProvider);
          ref.invalidate(dailyAttendanceProvider);
        },
        child: employeesAsync.when(
          data: (employees) {
            final staffMembers = employees.where((e) => e.role == 'staff').toList();

            return attendanceAsync.when(
              data: (attendanceLogs) {
                // Create lookup map of attendance logs by staff phone
                final Map<String, AttendanceModel> logMap = {};
                for (final log in attendanceLogs) {
                  logMap[log.staffPhone] = log;
                }

                // Metrics
                final totalStaff = staffMembers.length;
                final activeCount = attendanceLogs.where((l) => l.isActive).length;
                final completedCount = attendanceLogs.where((l) => !l.isActive && l.endTime != null).length;
                final presentCount = attendanceLogs.length;
                final absentCount = totalStaff - presentCount > 0 ? totalStaff - presentCount : 0;

                // Filter staff members based on search and status tab
                final query = _searchCtrl.text.trim().toLowerCase();
                final filteredStaff = staffMembers.where((staff) {
                  final nameMatch = staff.name.toLowerCase().contains(query);
                  final phoneMatch = staff.phoneNumber.contains(query);
                  if (!nameMatch && !phoneMatch) return false;

                  final log = logMap[staff.phoneNumber];
                  if (_selectedFilter == 'Active') {
                    return log != null && log.isActive;
                  } else if (_selectedFilter == 'Completed') {
                    return log != null && !log.isActive && log.endTime != null;
                  } else if (_selectedFilter == 'Absent') {
                    return log == null;
                  }
                  return true;
                }).toList();

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Date Selector Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref.read(adminAttendanceDateProvider.notifier).state =
                                  selectedDate.subtract(const Duration(days: 1));
                            },
                          ),
                          GestureDetector(
                            onTap: () => _selectDate(context, selectedDate),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  dateDisplayStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref.read(adminAttendanceDateProvider.notifier).state =
                                  selectedDate.add(const Duration(days: 1));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Metrics Grid
                    Row(
                      children: [
                        _buildMetricChip('Staff', '$totalStaff', AppColors.primary, isDark),
                        const SizedBox(width: 8),
                        _buildMetricChip('Active', '$activeCount', AppColors.success, isDark),
                        const SizedBox(width: 8),
                        _buildMetricChip('Completed', '$completedCount', const Color(0xFF3B82F6), isDark),
                        const SizedBox(width: 8),
                        _buildMetricChip('Absent', '$absentCount', AppColors.error, isDark),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Search Bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search staff by name or phone...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : AppColors.textTertiary,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() => _searchCtrl.clear()),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Filter Pills Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Active', 'Completed', 'Absent'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              backgroundColor: cardColor,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.borderDark : AppColors.border),
                              ),
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : AppColors.textSecondary),
                              ),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedFilter = filter);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Attendance Cards List
                    if (filteredStaff.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No attendance records match your criteria.',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredStaff.map((staff) {
                        final log = logMap[staff.phoneNumber];
                        return _buildStaffAttendanceCard(context, staff, log, isDark, cardColor);
                      }),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading attendance logs: $err'),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => Center(child: Text('Error loading employees: $err')),
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAttendanceCard(
    BuildContext context,
    TelecallerModel staff,
    AttendanceModel? log,
    bool isDark,
    Color cardColor,
  ) {
    final bool isPresent = log != null;
    final bool isActive = log != null && log.isActive;
    final bool isCompleted = log != null && !log.isActive && log.endTime != null;

    Color statusBg = isDark ? Colors.white10 : Colors.grey.shade100;
    Color statusTextColor = AppColors.textTertiary;
    String statusText = 'Absent';

    if (isActive) {
      statusBg = AppColors.success.withValues(alpha: 0.1);
      statusTextColor = AppColors.success;
      statusText = 'Active';
    } else if (isCompleted) {
      statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
      statusTextColor = const Color(0xFF3B82F6);
      final minutes = log.totalWorkingMinutes;
      statusText = 'Shift Completed (${_formatMinutes(minutes)})';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
            // Header Row: Avatar, Name, Phone, Role Badge & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isPresent
                      ? (isActive ? AppColors.success.withValues(alpha: 0.15) : const Color(0xFF3B82F6).withValues(alpha: 0.15))
                      : AppColors.error.withValues(alpha: 0.1),
                  child: Text(
                    staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: isPresent
                          ? (isActive ? AppColors.success : const Color(0xFF3B82F6))
                          : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            staff.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: staff.isFieldStaff
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              staff.isFieldStaff ? 'Field' : 'Office',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: staff.isFieldStaff ? AppColors.primary : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        staff.phoneNumber,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
            ),

            if (log != null) ...[
              const Divider(height: 24),

              // Timing Row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile(
                      icon: Icons.play_circle_fill_rounded,
                      iconColor: AppColors.success,
                      label: 'Started At',
                      value: DateFormat('hh:mm a').format(log.startTime),
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailTile(
                      icon: Icons.stop_circle_rounded,
                      iconColor: log.endTime != null ? AppColors.error : AppColors.textTertiary,
                      label: 'Ended At',
                      value: log.endTime != null ? DateFormat('hh:mm a').format(log.endTime!) : 'In Progress',
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailTile(
                      icon: Icons.timer_rounded,
                      iconColor: AppColors.primary,
                      label: 'Duration',
                      value: _formatMinutes(log.totalWorkingMinutes > 0
                          ? log.totalWorkingMinutes
                          : DateTime.now().difference(log.startTime).inMinutes),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selfie & Diagnostics Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                ),
                child: Row(
                  children: [
                    if (log.startSelfieUrl != null && log.startSelfieUrl!.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _showSelfieDialog(context, log.startSelfieUrl!, staff.name),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildSelfieImage(log.startSelfieUrl!, width: 50, height: 50),
                            ),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fullscreen_rounded, size: 10, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (log.startLatitude != 0.0 || log.startLongitude != 0.0)
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 13, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'GPS: ${log.startLatitude.toStringAsFixed(4)}, ${log.startLongitude.toStringAsFixed(4)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.battery_charging_full_rounded, size: 13, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text(
                                'Battery: ${log.startBattery}%${log.endBattery != null ? ' → ${log.endBattery}%' : ''}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.wifi_rounded, size: 13, color: AppColors.primaryLight),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  log.startNetwork,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
