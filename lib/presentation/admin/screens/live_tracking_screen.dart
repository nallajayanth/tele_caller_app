import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_management_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  String? _selectedStaffPhone;

  // Default Map center (Hyderabad, India)
  final LatLng _defaultCenter = const LatLng(17.3850, 78.4867);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Staff Tracker',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('staff_locations').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final docs = snapshot.data?.docs ?? [];
          final employees = employeesAsync.value ?? [];
          final fieldStaffPhones = employees
              .where((e) => e.isFieldStaff)
              .map((e) => e.phoneNumber)
              .toSet();

          final activeStaffList = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestampVal = data['timestamp'];
            DateTime? updatedTime;
            if (timestampVal is Timestamp) {
              updatedTime = timestampVal.toDate();
            }

            return _StaffLocationData(
              phoneNumber: doc.id,
              name: data['name'] as String? ?? 'Unknown Staff',
              latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
              isOnline: data['isOnline'] as bool? ?? false,
              lastUpdated: updatedTime,
            );
          }).where((staff) => fieldStaffPhones.contains(staff.phoneNumber)).toList();

          // Filter to show active coordinates
          final validLocations = activeStaffList.where((s) => s.latitude != 0.0 && s.longitude != 0.0).toList();

          // Generate map markers
          final List<Marker> markers = validLocations.map((staff) {
            final isSelected = _selectedStaffPhone == staff.phoneNumber;
            return Marker(
              point: LatLng(staff.latitude, staff.longitude),
              width: 120,
              height: 75,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedStaffPhone = staff.phoneNumber);
                  _mapController.move(LatLng(staff.latitude, staff.longitude), 15);
                  _showStaffDetailsSheet(context, staff, isDark);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: staff.isOnline ? AppColors.success : AppColors.textTertiary,
                          width: 1.5,
                        ),
                        boxShadow: AppShadows.card,
                      ),
                      child: Text(
                        staff.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Marker Pin
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: (staff.isOnline ? AppColors.success : AppColors.textTertiary).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Icon(
                          Icons.location_on_rounded,
                          size: 26,
                          color: staff.isOnline ? AppColors.success : AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              // 1. OpenStreetMap Tile Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: validLocations.isNotEmpty 
                      ? LatLng(validLocations.first.latitude, validLocations.first.longitude)
                      : _defaultCenter,
                  initialZoom: 13.0,
                  maxZoom: 18.0,
                  minZoom: 4.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ht.telecaller_mobile_app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // 2. Horizontal staff list card overlay
              if (validLocations.isNotEmpty)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: validLocations.length,
                    itemBuilder: (ctx, index) {
                      final staff = validLocations[index];
                      final isSelected = _selectedStaffPhone == staff.phoneNumber;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedStaffPhone = staff.phoneNumber);
                          _mapController.move(LatLng(staff.latitude, staff.longitude), 15.5);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          width: 170,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? AppColors.primary 
                                  : (isDark ? AppColors.borderDark : AppColors.border),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: AppShadows.card,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                staff.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: staff.isOnline ? AppColors.success : AppColors.textTertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    staff.isOnline ? 'Online' : 'Offline',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: staff.isOnline ? AppColors.success : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 3. Placeholder if no staff locations exist
              if (validLocations.isEmpty)
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No staff members have started a shift yet.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showStaffDetailsSheet(BuildContext context, _StaffLocationData staff, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (ctx) {
        final timeStr = staff.lastUpdated != null 
            ? DateFormat('hh:mm a (dd MMM)').format(staff.lastUpdated!)
            : 'Never';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      staff.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (staff.isOnline ? AppColors.success : AppColors.textTertiary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        staff.isOnline ? 'Active Shift' : 'Off Duty',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: staff.isOnline ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Phone: ${staff.phoneNumber}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.update_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Last GPS Ping: $timeStr',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.explore_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location: ${staff.latitude.toStringAsFixed(5)}, ${staff.longitude.toStringAsFixed(5)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StaffLocationData {
  final String phoneNumber;
  final String name;
  final double latitude;
  final double longitude;
  final bool isOnline;
  final DateTime? lastUpdated;

  const _StaffLocationData({
    required this.phoneNumber,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    this.lastUpdated,
  });
}
