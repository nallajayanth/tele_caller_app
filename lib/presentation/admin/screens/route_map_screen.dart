import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/visit_model.dart';
import '../../../data/models/route_point_model.dart';

class RouteMapScreen extends ConsumerStatefulWidget {
  final String staffPhone;
  final String staffName;
  final String dateStr;

  const RouteMapScreen({
    super.key,
    required this.staffPhone,
    required this.staffName,
    required this.dateStr,
  });

  @override
  ConsumerState<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends ConsumerState<RouteMapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  double _replayProgress = 1.0;
  bool _isLoading = true;

  double _totalDistance = 0.0;
  Duration _travelTime = Duration.zero;
  Duration _idleTime = Duration.zero;
  Duration _workingTime = Duration.zero;
  List<TimelineEvent> _timelineEvents = [];

  @override
  void initState() {
    super.initState();
    _fetchRouteHistory();
  }

  Future<void> _fetchRouteHistory() async {
    try {
      final docId = '${widget.staffPhone}_${widget.dateStr}';
      
      // 1. Fetch attendance log metadata (for shift details & total_km)
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(docId)
          .get();

      double firebaseTotalKm = 0.0;
      AttendanceModel? attendance;
      if (attendanceDoc.exists) {
        final data = attendanceDoc.data();
        if (data != null) {
          firebaseTotalKm = (data['total_km'] as num?)?.toDouble() ?? 0.0;
          try {
            attendance = AttendanceModel.fromJson(data);
          } catch (e) {
            debugPrint('Failed to parse AttendanceModel: $e');
          }
        }
      }

      // 2. Fetch background route points history
      final snap = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(docId)
          .collection('route_points')
          .orderBy('timestamp', descending: false)
          .get();

      final List<RoutePointModel> pointsList = snap.docs.map((doc) {
        return RoutePointModel.fromJson(doc.data());
      }).toList();

      final points = pointsList
          .map((p) => LatLng(p.latitude, p.longitude))
          .where((p) => p.latitude != 0.0 && p.longitude != 0.0)
          .toList();

      // 3. Fetch customer visits for geotag stop markers and verification stats
      final visitSnap = await FirebaseFirestore.instance
          .collection('customer_visits')
          .where('staff_phone', isEqualTo: widget.staffPhone)
          .get();

      final dayVisits = <VisitModel>[];
      final visitLatLngs = <LatLng>[];

      for (final doc in visitSnap.docs) {
        final data = doc.data();
        try {
          final visit = VisitModel.fromJson(data);
          final timeStr = visit.arrivalTime.toIso8601String();
          if (timeStr.startsWith(widget.dateStr)) {
            dayVisits.add(visit);
            if (visit.arrivalLat != 0.0 && visit.arrivalLng != 0.0) {
              visitLatLngs.add(LatLng(visit.arrivalLat, visit.arrivalLng));
            }
          }
        } catch (e) {
          debugPrint('Failed to parse VisitModel: $e');
        }
      }
      dayVisits.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

      // 4. Merge visit geotags into journey points if missing
      final unifiedPoints = List<LatLng>.from(points);
      for (final v in visitLatLngs) {
        if (!unifiedPoints.any((p) => (p.latitude - v.latitude).abs() < 0.0001 && (p.longitude - v.longitude).abs() < 0.0001)) {
          unifiedPoints.add(v);
        }
      }

      // 5. Calculate travel statistics (Distance, Travel Time, Idle Time, Work Time)
      double calculatedDistance = 0.0;
      Duration calculatedTravelTime = Duration.zero;
      Duration calculatedIdleTime = Duration.zero;

      for (int i = 0; i < pointsList.length - 1; i++) {
        final p1 = pointsList[i];
        final p2 = pointsList[i + 1];
        final dt = p2.timestamp.difference(p1.timestamp);

        // Filter out extreme gaps (e.g. overnight or app restarts)
        if (dt.inSeconds <= 0 || dt.inHours > 6) continue;

        final dist = Geolocator.distanceBetween(
          p1.latitude,
          p1.longitude,
          p2.latitude,
          p2.longitude,
        );

        calculatedDistance += dist / 1000.0; // in km

        final speed = dist / dt.inSeconds; // m/s
        if (speed > 0.5 && dist > 10.0) {
          calculatedTravelTime += dt;
        } else {
          calculatedIdleTime += dt;
        }
      }

      final workingTime = attendance != null
          ? (attendance.endTime ?? DateTime.now()).difference(attendance.startTime)
          : Duration.zero;

      // 6. Build chronological Route Timeline Events
      final events = <TimelineEvent>[];

      if (attendance != null) {
        events.add(TimelineEvent(
          type: TimelineEventType.dutyStart,
          timestamp: attendance.startTime,
          title: 'Duty Started',
          description: 'Battery: ${attendance.startBattery}% • Network: ${attendance.startNetwork}',
          subtitle: 'Location: ${attendance.startLatitude.toStringAsFixed(4)}, ${attendance.startLongitude.toStringAsFixed(4)}',
          latitude: attendance.startLatitude,
          longitude: attendance.startLongitude,
        ));
      }

      for (final visit in dayVisits) {
        final arrTimeStr = DateFormat('hh:mm a').format(visit.arrivalTime);
        final depTimeStr = visit.departureTime != null
            ? DateFormat('hh:mm a').format(visit.departureTime!)
            : 'N/A';
        events.add(TimelineEvent(
          type: TimelineEventType.visit,
          timestamp: visit.arrivalTime,
          title: 'Visit Stop: ${visit.customerName}',
          description: 'Remarks: ${visit.remarks}',
          subtitle: 'Arrival: $arrTimeStr • Departure: $depTimeStr',
          isLocationMismatch: visit.isLocationMismatch,
          photoUrl: visit.photoUrl,
          durationStr: '${visit.visitDurationMinutes} mins',
          latitude: visit.arrivalLat,
          longitude: visit.arrivalLng,
        ));
      }

      if (attendance != null) {
        if (!attendance.isActive && attendance.endTime != null) {
          events.add(TimelineEvent(
            type: TimelineEventType.dutyEnd,
            timestamp: attendance.endTime!,
            title: 'Duty Ended',
            description: 'Battery: ${attendance.endBattery}% • Network: ${attendance.endNetwork ?? 'Online'}',
            subtitle: 'Location: ${attendance.endLatitude?.toStringAsFixed(4)}, ${attendance.endLongitude?.toStringAsFixed(4)}',
            latitude: attendance.endLatitude,
            longitude: attendance.endLongitude,
          ));
        } else {
          events.add(TimelineEvent(
            type: TimelineEventType.dutyEnd,
            timestamp: DateTime.now(),
            title: 'Shift Active (In Progress)',
            description: 'Staff member is currently active on the field.',
            subtitle: 'Current Time: ${DateFormat('hh:mm a').format(DateTime.now())}',
          ));
        }
      }

      // Sort timeline events chronologically
      events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        setState(() {
          _routePoints = unifiedPoints;
          _totalDistance = firebaseTotalKm > 0.0 ? firebaseTotalKm : calculatedDistance;
          _travelTime = calculatedTravelTime;
          _idleTime = calculatedIdleTime;
          _workingTime = workingTime;
          _timelineEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load route history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = (_routePoints.length * _replayProgress).round();
    final visiblePoints = _routePoints.take(visibleCount).toList();

    final center = _routePoints.isNotEmpty
        ? _routePoints.last
        : const LatLng(17.3850, 78.4867);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Map & Replay',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.staffName} (${widget.dateStr})',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.telecaller_mobile_app',
                    ),
                    if (visiblePoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: visiblePoints,
                            strokeWidth: 4.0,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    if (visiblePoints.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: visiblePoints.first,
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.success, size: 36),
                          ),
                          Marker(
                            point: visiblePoints.last,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
                
                // Route Replay Slider Card (Repositioned to top of the screen)
                if (_routePoints.length > 1)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Route Replay ($visibleCount / ${_routePoints.length} Points)',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.refresh_rounded, size: 20),
                                  onPressed: () => setState(() => _replayProgress = 1.0),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Slider(
                              value: _replayProgress,
                              onChanged: (val) => setState(() => _replayProgress = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Draggable Scrollable Sheet for Timeline & Stats Analytics
                DraggableScrollableSheet(
                  initialChildSize: 0.32,
                  minChildSize: 0.12,
                  maxChildSize: 0.85,
                  builder: (context, scrollController) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

                    return Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Drag Handle
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white24 : Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Daily Travel Stats Header
                          Text(
                            'Daily Movement Analytics',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Stats Cards Row (Daily KM Travel: dist, travel, idle, work time)
                          Row(
                            children: [
                              _buildStatCard('Distance', '${_totalDistance.toStringAsFixed(1)} KM', Icons.directions_walk_rounded, AppColors.primary, isDark),
                              const SizedBox(width: 8),
                              _buildStatCard('Travel Time', _formatDuration(_travelTime), Icons.drive_eta_rounded, AppColors.success, isDark),
                              const SizedBox(width: 8),
                              _buildStatCard('Idle Time', _formatDuration(_idleTime), Icons.bedtime_rounded, Colors.orange, isDark),
                              const SizedBox(width: 8),
                              _buildStatCard('Work Time', _formatDuration(_workingTime), Icons.work_rounded, AppColors.accent, isDark),
                            ],
                          ),

                          const Divider(height: 24),

                          // Timeline Header
                          Text(
                            'Route Timeline',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Timeline List (Route Timeline & Visit Verification metrics)
                          if (_timelineEvents.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No timeline data available for today.',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _timelineEvents.length,
                              itemBuilder: (ctx, idx) {
                                return _buildTimelineTile(_timelineEvents[idx], idx == 0, idx == _timelineEvents.length - 1, isDark);
                              },
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
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

  Widget _buildTimelineTile(TimelineEvent event, bool isFirst, bool isLast, bool isDark) {
    Color dotColor = AppColors.primary;
    IconData icon = Icons.circle;

    if (event.type == TimelineEventType.dutyStart) {
      dotColor = AppColors.success;
      icon = Icons.play_arrow_rounded;
    } else if (event.type == TimelineEventType.dutyEnd) {
      dotColor = AppColors.error;
      icon = Icons.stop_rounded;
    } else {
      dotColor = event.isLocationMismatch == true ? AppColors.error : AppColors.accent;
      icon = Icons.location_on_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 2,
                height: 10,
                color: isFirst ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 1.5),
                ),
                child: Icon(icon, size: 14, color: dotColor),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.border,
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
                            event.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(event.timestamp),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (event.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      event.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (event.type == TimelineEventType.visit) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 10),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            event.isLocationMismatch == true ? Icons.cancel_rounded : Icons.check_circle_rounded,
                            size: 14,
                            color: event.isLocationMismatch == true ? AppColors.error : AppColors.success,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.isLocationMismatch == true
                                  ? 'Location Mismatch (> 100 meters limit)'
                                  : 'GPS Location Match Verified (< 100m)',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: event.isLocationMismatch == true ? AppColors.error : AppColors.success),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            event.photoUrl != null && event.photoUrl!.isNotEmpty ? Icons.photo_camera_rounded : Icons.no_photography_rounded,
                            size: 14,
                            color: event.photoUrl != null && event.photoUrl!.isNotEmpty ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.photoUrl != null && event.photoUrl!.isNotEmpty
                                  ? 'Photo Proof Uploaded'
                                  : 'Missing Photo Proof',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: event.photoUrl != null && event.photoUrl!.isNotEmpty ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (event.photoUrl != null && event.photoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showTimelinePhotoDialog(event.photoUrl!, event.title),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildVisitProofImage(
                              event.photoUrl!,
                              width: 80,
                              height: 60,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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
        errorBuilder: (_, _, _) => _photoErrorPlaceholder(width, height),
      );
    } else if (url.startsWith('/') || url.contains(':\\') || url.startsWith('file://')) {
      final cleanPath = url.startsWith('file://') ? url.substring(7) : url;
      return Image.file(
        File(cleanPath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _photoErrorPlaceholder(width, height),
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
          errorBuilder: (_, _, _) => _photoErrorPlaceholder(width, height),
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

  void _showTimelinePhotoDialog(String photoUrl, String title) {
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
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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

enum TimelineEventType { dutyStart, visit, dutyEnd }

class TimelineEvent {
  final TimelineEventType type;
  final DateTime timestamp;
  final String title;
  final String description;
  final String? subtitle;
  final bool? isLocationMismatch;
  final String? photoUrl;
  final String? durationStr;
  final double? latitude;
  final double? longitude;

  const TimelineEvent({
    required this.type,
    required this.timestamp,
    required this.title,
    required this.description,
    this.subtitle,
    this.isLocationMismatch,
    this.photoUrl,
    this.durationStr,
    this.latitude,
    this.longitude,
  });
}
