import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchRouteHistory();
  }

  Future<void> _fetchRouteHistory() async {
    try {
      final docId = '${widget.staffPhone}_${widget.dateStr}';
      final snap = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(docId)
          .collection('route_points')
          .orderBy('timestamp', descending: false)
          .get();

      final points = snap.docs.map((doc) {
        final data = doc.data();
        return LatLng(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _routePoints = points;
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
                // Route Replay Slider Card (SRS #3)
                if (_routePoints.length > 1)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Route Replay ($visibleCount / ${_routePoints.length} Points)',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded),
                                  onPressed: () => setState(() => _replayProgress = 1.0),
                                ),
                              ],
                            ),
                            Slider(
                              value: _replayProgress,
                              onChanged: (val) => setState(() => _replayProgress = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
