import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'route_map_screen.dart';
import 'user_management_screen.dart';
import 'notifications_screen.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  String? _selectedStaffPhone;
  bool _showRouteLine = true;
  bool _showVisitMarkers = true;
  bool _isTelemetryCardCollapsed = false;

  List<LatLng> _routePoints = [];
  List<_MapVisitData> _visitLogs = [];
  bool _isLoadingRoute = false;
  bool _hasAutoCentered = false;

  void _checkAutoSelectAndCenter(List<_StaffLocationData> validLocations) {
    if (_hasAutoCentered || validLocations.isEmpty) return;

    final targetStaff = validLocations.where((s) => s.isOnline).firstOrNull ?? validLocations.first;
    _hasAutoCentered = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _listenToStaffRouteAndVisits(targetStaff.phoneNumber, targetStaff.name);
      if (targetStaff.latitude != 0.0 && targetStaff.longitude != 0.0) {
        _mapController.move(LatLng(targetStaff.latitude, targetStaff.longitude), 14.5);
      }
    });
  }

  void _recenterToStaff(List<_StaffLocationData> validLocations) {
    if (_selectedStaffPhone != null) {
      final selected = validLocations.where((s) => s.phoneNumber == _selectedStaffPhone).firstOrNull;
      if (selected != null && selected.latitude != 0.0) {
        _mapController.move(LatLng(selected.latitude, selected.longitude), 15.0);
        return;
      }
    }

    if (_routePoints.isNotEmpty) {
      _mapController.move(_routePoints.last, 15.0);
      return;
    }

    if (validLocations.isNotEmpty) {
      final first = validLocations.where((s) => s.isOnline).firstOrNull ?? validLocations.first;
      _mapController.move(LatLng(first.latitude, first.longitude), 14.5);
    }
  }

  StreamSubscription? _routeSub;
  StreamSubscription? _visitSub;

  // Default Map center (Hyderabad, India)
  final LatLng _defaultCenter = const LatLng(17.3850, 78.4867);

  @override
  void dispose() {
    _routeSub?.cancel();
    _visitSub?.cancel();
    super.dispose();
  }

  void _listenToStaffRouteAndVisits(String phone, String name) {
    if (_selectedStaffPhone == phone && (_routeSub != null || _visitSub != null)) return;

    _routeSub?.cancel();
    _visitSub?.cancel();

    setState(() {
      _selectedStaffPhone = phone;
      _isLoadingRoute = true;
    });

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final attendanceDocId = '${phone}_$dateStr';

    // 1. Listen to background GPS route points in real-time
    _routeSub = FirebaseFirestore.instance
        .collection('attendance_logs')
        .doc(attendanceDocId)
        .collection('route_points')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((routeSnap) {
      final points = routeSnap.docs.map((doc) {
        final data = doc.data();
        final lat = (data['latitude'] ?? data['arrival_lat'] ?? 0.0) as num;
        final lng = (data['longitude'] ?? data['arrival_lng'] ?? 0.0) as num;
        return LatLng(lat.toDouble(), lng.toDouble());
      }).where((p) => p.latitude != 0.0 && p.longitude != 0.0).toList();

      _updateMapState(points: points);
    }, onError: (e) {
      debugPrint('Error listening to route points: $e');
      if (mounted) setState(() => _isLoadingRoute = false);
    });

    // 2. Listen to geotagged visits in real-time
    _visitSub = FirebaseFirestore.instance
        .collection('customer_visits')
        .where('staff_phone', isEqualTo: phone)
        .snapshots()
        .listen((visitSnap) {
      final visits = <_MapVisitData>[];
      int stopIndex = 1;

      for (final doc in visitSnap.docs) {
        final data = doc.data();
        final latNum = (data['arrival_lat'] ?? data['arrival_latitude'] ?? data['latitude'] ?? 0.0) as num;
        final lngNum = (data['arrival_lng'] ?? data['arrival_longitude'] ?? data['longitude'] ?? 0.0) as num;

        final lat = latNum.toDouble();
        final lng = lngNum.toDouble();

        DateTime time = now;
        final arrTime = data['arrival_time'];
        if (arrTime is Timestamp) {
          time = arrTime.toDate();
        } else if (arrTime is String) {
          time = DateTime.tryParse(arrTime) ?? now;
        }

        DateTime? depTime;
        final departureVal = data['departure_time'];
        if (departureVal is Timestamp) {
          depTime = departureVal.toDate();
        } else if (departureVal is String) {
          depTime = DateTime.tryParse(departureVal);
        }

        final duration = (data['visit_duration_minutes'] as num?)?.toInt() ?? 0;

        if (lat != 0.0 && lng != 0.0 && time.year == now.year && time.month == now.month && time.day == now.day) {
          visits.add(_MapVisitData(
            id: doc.id,
            stopNumber: stopIndex++,
            customerName: data['customer_name'] as String? ?? 'Customer',
            customerType: data['customer_type'] as String? ?? 'Doctor',
            address: data['address'] as String? ?? '',
            remarks: data['remarks'] as String? ?? '',
            arrivalTime: time,
            departureTime: depTime,
            visitDurationMinutes: duration,
            latitude: lat,
            longitude: lng,
            photoUrl: data['photo_url'] as String?,
            isMismatch: data['is_location_mismatch'] as bool? ?? false,
            staffName: data['staff_name'] as String? ?? 'Staff Member',
            staffPhone: data['staff_phone'] as String? ?? '',
          ));
        }
      }

      visits.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
      for (int i = 0; i < visits.length; i++) {
        visits[i] = visits[i].copyWith(stopNumber: i + 1);
      }

      _updateMapState(visits: visits);
    }, onError: (e) {
      debugPrint('Error listening to customer visits: $e');
      if (mounted) setState(() => _isLoadingRoute = false);
    });
  }

  void _updateMapState({List<LatLng>? points, List<_MapVisitData>? visits}) {
    if (!mounted) return;

    final newPoints = points ?? _routePoints;
    final newVisits = visits ?? _visitLogs;

    // Build unified journey path containing all points & visit geotags
    final unifiedPoints = List<LatLng>.from(newPoints);
    for (final v in newVisits) {
      final p = LatLng(v.latitude, v.longitude);
      if (!unifiedPoints.any((existing) => (existing.latitude - p.latitude).abs() < 0.0001 && (existing.longitude - p.longitude).abs() < 0.0001)) {
        unifiedPoints.add(p);
      }
    }

    setState(() {
      _routePoints = unifiedPoints;
      _visitLogs = newVisits;
      _isLoadingRoute = false;
    });

    final targetCenter = newVisits.isNotEmpty
        ? LatLng(newVisits.last.latitude, newVisits.last.longitude)
        : (unifiedPoints.isNotEmpty ? unifiedPoints.last : null);

    if (targetCenter != null) {
      _mapController.move(targetCenter, 14.5);
    }
  }

  void _showVisitDetailsSheet(BuildContext context, _MapVisitData visit, bool isDark) {
    final dateStr = DateFormat('dd MMM yyyy').format(visit.arrivalTime);
    final arrTimeStr = DateFormat('hh:mm a').format(visit.arrivalTime);
    final depTimeStr = visit.departureTime != null
        ? DateFormat('hh:mm a').format(visit.departureTime!)
        : 'N/A';

    final int durationMin = visit.visitDurationMinutes;
    String durationStr = '0 mins';
    if (durationMin > 0) {
      if (durationMin < 60) {
        durationStr = '$durationMin mins';
      } else {
        final hrs = durationMin ~/ 60;
        final mins = durationMin % 60;
        durationStr = mins > 0 ? '$hrs hr $mins mins' : '$hrs hr';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Visit Stop #${visit.stopNumber}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                visit.customerName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              if (visit.customerType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Type: ${visit.customerType.toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Timing Details Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Arrival',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          arrTimeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 24, color: isDark ? Colors.white24 : Colors.black12),
                    Column(
                      children: [
                        Text(
                          'Departure',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          depTimeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 24, color: isDark ? Colors.white24 : Colors.black12),
                    Column(
                      children: [
                        Text(
                          'Stop Duration',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              durationStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              if (visit.address.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        visit.address,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              if (visit.remarks.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Remarks: ${visit.remarks}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              if (visit.isMismatch) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location Mismatch Alert: Arrival was > 100m from registered location.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (visit.photoUrl != null && visit.photoUrl!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Photo Proof (Tap to expand):',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showFullPhotoDialog(context, visit.photoUrl!, 'Photo Proof: ${visit.customerName}'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: _buildPhotoWidget(visit.photoUrl!),
                          ),
                          Container(
                            color: Colors.black.withValues(alpha: 0.15),
                          ),
                          const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RouteMapScreen(
                        staffPhone: visit.staffPhone.isNotEmpty ? visit.staffPhone : (_selectedStaffPhone ?? ''),
                        staffName: visit.staffName.isNotEmpty ? visit.staffName : visit.customerName,
                        dateStr: todayStr,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                label: Text(
                  'Open Full Route Replay',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPhotoWidget(String photoUrl, {BoxFit fit = BoxFit.cover}) {
    if (photoUrl.startsWith('http')) {
      return Image.network(
        photoUrl,
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_rounded),
      );
    } else if (photoUrl.startsWith('/') || photoUrl.contains(':\\') || photoUrl.startsWith('file://')) {
      final cleanPath = photoUrl.startsWith('file://') ? photoUrl.substring(7) : photoUrl;
      return Image.file(
        File(cleanPath),
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_rounded),
      );
    }
    try {
      final cleanBase64 = photoUrl.contains(',') ? photoUrl.split(',').last : photoUrl;
      final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_rounded),
      );
    } catch (_) {
      return const Icon(Icons.image_not_supported_rounded);
    }
  }

  void _showFullPhotoDialog(BuildContext context, String photoUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  width: double.infinity,
                  color: Colors.black,
                  child: _buildPhotoWidget(photoUrl, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final employeesAsync = ref.watch(employeesProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Staff & Route Tracker',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Badge(
                label: count > 0 ? Text('$count') : null,
                isLabelVisible: count > 0,
                child: IconButton(
                  tooltip: 'Security Alerts',
                  icon: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _showRouteLine ? 'Hide Route Line' : 'Show Route Line',
            icon: Icon(
              Icons.route_rounded,
              color: _showRouteLine ? AppColors.primary : AppColors.textTertiary,
            ),
            onPressed: () => setState(() => _showRouteLine = !_showRouteLine),
          ),
          IconButton(
            tooltip: _showVisitMarkers ? 'Hide Visits' : 'Show Visits',
            icon: Icon(
              Icons.pin_drop_rounded,
              color: _showVisitMarkers ? AppColors.accent : AppColors.textTertiary,
            ),
            onPressed: () => setState(() => _showVisitMarkers = !_showVisitMarkers),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance_logs')
            .where('date', isEqualTo: todayStr)
            .snapshots(),
        builder: (context, attendanceSnap) {
          final attendanceDocs = attendanceSnap.data?.docs ?? [];
          final Map<String, dynamic> activeDutyLogs = {};
          for (final doc in attendanceDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final isActive = data['is_active'] as bool? ?? false;
            final phone = data['staff_phone'] as String?;
            if (isActive && phone != null && phone.isNotEmpty) {
              activeDutyLogs[phone] = data;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('staff_locations').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !attendanceSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final docs = snapshot.data?.docs ?? [];
              final employees = employeesAsync.value ?? [];
              final fieldStaffList = employees.where((e) => e.isFieldStaff).toList();
              final fieldStaffPhones = fieldStaffList.map((e) => e.phoneNumber).toSet();

              final activeStaffList = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final phone = doc.id;
                final timestampVal = data['timestamp'];
                DateTime? updatedTime;
                if (timestampVal is Timestamp) {
                  updatedTime = timestampVal.toDate();
                }

                final rawIsOnline = data['isOnline'] as bool? ?? false;
                final isRecentPing = updatedTime != null &&
                    DateTime.now().difference(updatedTime).inMinutes < 15;

                final activeLog = activeDutyLogs[phone];
                final hasActiveDuty = activeLog != null;

                final isOnline = hasActiveDuty || (rawIsOnline && isRecentPing);

                double lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
                double lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;

                if ((lat == 0.0 || lng == 0.0) && activeLog != null) {
                  lat = (activeLog['start_latitude'] as num?)?.toDouble() ?? 0.0;
                  lng = (activeLog['start_longitude'] as num?)?.toDouble() ?? 0.0;
                }

                return _StaffLocationData(
                  phoneNumber: phone,
                  name: data['name'] as String? ?? (activeLog?['staff_name'] as String? ?? 'Unknown Staff'),
                  latitude: lat,
                  longitude: lng,
                  isOnline: isOnline,
                  lastUpdated: updatedTime,
                  speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
                  isMocked: data['isMocked'] as bool? ?? false,
                  batteryLevel: (data['batteryLevel'] as num?)?.toInt() ?? (activeLog?['start_battery'] as num?)?.toInt() ?? 100,
                  networkStatus: data['networkStatus'] as String? ?? (activeLog?['start_network'] as String?) ?? 'Online',
                );
              }).where((staff) => fieldStaffPhones.contains(staff.phoneNumber)).toList();

              for (final staff in fieldStaffList) {
                final phone = staff.phoneNumber;
                final activeLog = activeDutyLogs[phone];
                if (activeLog != null && !activeStaffList.any((s) => s.phoneNumber == phone)) {
                  final startLat = (activeLog['start_latitude'] as num?)?.toDouble() ?? 0.0;
                  final startLng = (activeLog['start_longitude'] as num?)?.toDouble() ?? 0.0;
                  activeStaffList.add(_StaffLocationData(
                    phoneNumber: phone,
                    name: staff.name,
                    latitude: startLat,
                    longitude: startLng,
                    isOnline: true,
                    batteryLevel: (activeLog['start_battery'] as num?)?.toInt() ?? 100,
                    networkStatus: activeLog['start_network'] as String? ?? 'Online',
                  ));
                }
              }

              final validLocations = activeStaffList.where((s) => s.latitude != 0.0 && s.longitude != 0.0).toList();
              _checkAutoSelectAndCenter(validLocations);

              // Generate live staff markers
              final List<Marker> staffMarkers = validLocations.map((staff) {
                final isSelected = _selectedStaffPhone == staff.phoneNumber;
                return Marker(
                  point: LatLng(staff.latitude, staff.longitude),
                  width: 120,
                  height: 75,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _listenToStaffRouteAndVisits(staff.phoneNumber, staff.name);
                      if (staff.latitude != 0.0 && staff.longitude != 0.0) {
                        _mapController.move(LatLng(staff.latitude, staff.longitude), 14.5);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

              // Generate visit log markers
              final List<Marker> visitMarkers = _showVisitMarkers
                  ? _visitLogs.map((visit) {
                      return Marker(
                        point: LatLng(visit.latitude, visit.longitude),
                        width: 120,
                        height: 60,
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showVisitDetailsSheet(context, visit, isDark);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: AppShadows.card,
                                ),
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: AppColors.accent,
                                  child: Text(
                                    '${visit.stopNumber}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: AppShadows.card,
                                ),
                                child: Text(
                                  'Stop #${visit.stopNumber}: ${visit.customerName}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList()
                  : [];

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
                      if (_showRouteLine && _routePoints.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 4.5,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      MarkerLayer(markers: [...visitMarkers, ...staffMarkers]),
                    ],
                  ),

                  // 2. Loading Indicator for Route & Visit Fetching
                  if (_isLoadingRoute)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: AppShadows.card,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Fetching route...',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Recenter Button Floating Action
                  Positioned(
                    top: 16,
                    left: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_map',
                      backgroundColor: cardColor,
                      foregroundColor: AppColors.primary,
                      elevation: 3,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _recenterToStaff(validLocations);
                      },
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ),

                  // Telemetry details card overlay for the selected staff member
                  if (_selectedStaffPhone != null)
                    _buildSelectedStaffTelemetryCard(validLocations, activeDutyLogs, isDark, cardColor),

                  // 4. Horizontal Staff Bar Overlay
                  if (fieldStaffList.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      height: 95,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: fieldStaffList.length,
                        itemBuilder: (ctx, index) {
                          final staff = fieldStaffList[index];
                          final isSelected = _selectedStaffPhone == staff.phoneNumber;

                          final locData = validLocations.where((l) => l.phoneNumber == staff.phoneNumber).firstOrNull;
                          final activeLog = activeDutyLogs[staff.phoneNumber];
                          final isOnline = activeLog != null || (locData?.isOnline ?? false);

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _listenToStaffRouteAndVisits(staff.phoneNumber, staff.name);
                              if (locData != null && locData.latitude != 0.0) {
                                _mapController.move(LatLng(locData.latitude, locData.longitude), 14.5);
                              } else {
                                _recenterToStaff(validLocations);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              width: 180,
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          staff.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: isOnline ? AppColors.success : AppColors.textTertiary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOnline ? 'Active On Duty' : 'Off Duty',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isOnline ? AppColors.success : AppColors.textSecondary,
                                    ),
                                  ),
                                  if (isSelected && _visitLogs.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_visitLogs.length} visit stops logged',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectedStaffTelemetryCard(
    List<_StaffLocationData> validLocations,
    Map<String, dynamic> activeDutyLogs,
    bool isDark,
    Color cardColor,
  ) {
    final locData = validLocations.where((l) => l.phoneNumber == _selectedStaffPhone).firstOrNull;
    if (locData == null) return const SizedBox.shrink();

    final activeLog = activeDutyLogs[_selectedStaffPhone];
    final totalKm = (activeLog?['total_km'] as num?)?.toDouble() ?? 0.0;

    // Calculate working hours
    Duration workDuration = Duration.zero;
    if (activeLog != null && activeLog['start_time'] != null) {
      try {
        final start = DateTime.parse(activeLog['start_time'] as String);
        workDuration = DateTime.now().difference(start);
      } catch (_) {}
    }

    // Completed visits count
    final completedVisits = _visitLogs.length;

    // Estimate speed in km/h
    final speedKmH = locData.speed * 3.6;

    return Positioned(
      top: 72,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        color: cardColor.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name & Online Status & Mismatch Flag if mocked & Collapse Button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      locData.name,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  if (locData.isMocked)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('MOCK GPS', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.error)),
                    ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: locData.isOnline ? AppColors.success : AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    locData.isOnline ? 'Online' : 'Offline',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: locData.isOnline ? AppColors.success : AppColors.textTertiary),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isTelemetryCardCollapsed = !_isTelemetryCardCollapsed;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isTelemetryCardCollapsed
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              if (!_isTelemetryCardCollapsed) ...[
                const SizedBox(height: 10),
                // Diagnostics Grid Row (Speed, Battery, Network)
                Row(
                  children: [
                    _buildTelemetryMiniBox('SPEED', '${speedKmH.toStringAsFixed(1)} km/h', Icons.speed_rounded, AppColors.primary, isDark),
                    const SizedBox(width: 8),
                    _buildTelemetryMiniBox('BATTERY', '${locData.batteryLevel}%', Icons.battery_charging_full_rounded, Colors.orange, isDark),
                    const SizedBox(width: 8),
                    _buildTelemetryMiniBox('NETWORK', locData.networkStatus, Icons.wifi_rounded, AppColors.success, isDark),
                  ],
                ),
                const SizedBox(height: 8),
                // Analytics Summary Row (KM, Working Hours, Completed/Pending Visits)
                Row(
                  children: [
                    _buildTelemetryMiniBox('DISTANCE', '${totalKm.toStringAsFixed(1)} KM', Icons.directions_walk_rounded, AppColors.primary, isDark),
                    const SizedBox(width: 8),
                    _buildTelemetryMiniBox('WORK HOURS', _formatDuration(workDuration), Icons.work_rounded, AppColors.accent, isDark),
                    const SizedBox(width: 8),
                    _buildTelemetryMiniBox('VISITS', '$completedVisits Logged', Icons.playlist_add_check_rounded, Colors.teal, isDark),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    if (mins <= 0) return '0m';
    if (mins < 60) return '${mins}m';
    final hrs = mins ~/ 60;
    final remainingMins = mins % 60;
    return remainingMins > 0 ? '${hrs}h ${remainingMins}m' : '${hrs}h';
  }

  Widget _buildTelemetryMiniBox(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
  final double speed;
  final bool isMocked;
  final int batteryLevel;
  final String networkStatus;

  const _StaffLocationData({
    required this.phoneNumber,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    this.lastUpdated,
    this.speed = 0.0,
    this.isMocked = false,
    this.batteryLevel = 100,
    this.networkStatus = 'Online',
  });
}

class _MapVisitData {
  final String id;
  final int stopNumber;
  final String customerName;
  final String customerType;
  final String address;
  final String remarks;
  final DateTime arrivalTime;
  final DateTime? departureTime;
  final int visitDurationMinutes;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final bool isMismatch;
  final String staffName;
  final String staffPhone;

  const _MapVisitData({
    required this.id,
    required this.stopNumber,
    required this.customerName,
    required this.customerType,
    required this.address,
    required this.remarks,
    required this.arrivalTime,
    this.departureTime,
    this.visitDurationMinutes = 0,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    this.isMismatch = false,
    required this.staffName,
    required this.staffPhone,
  });

  _MapVisitData copyWith({
    int? stopNumber,
  }) {
    return _MapVisitData(
      id: id,
      stopNumber: stopNumber ?? this.stopNumber,
      customerName: customerName,
      customerType: customerType,
      address: address,
      remarks: remarks,
      arrivalTime: arrivalTime,
      departureTime: departureTime,
      visitDurationMinutes: visitDurationMinutes,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl,
      isMismatch: isMismatch,
      staffName: staffName,
      staffPhone: staffPhone,
    );
  }
}
