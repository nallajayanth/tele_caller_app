import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

class PerformanceScoreScreen extends StatelessWidget {
  final String staffName;
  final double totalKm;
  final int totalVisits;
  final int photoCount;
  final int mismatchCount;
  final DateTime? dutyStartTime;
  final int totalWorkingMinutes;
  final int totalIdleMinutes;
  final double avgVisitDurationMinutes;

  const PerformanceScoreScreen({
    super.key,
    required this.staffName,
    required this.totalKm,
    required this.totalVisits,
    required this.photoCount,
    required this.mismatchCount,
    this.dutyStartTime,
    this.totalWorkingMinutes = 0,
    this.totalIdleMinutes = 0,
    this.avgVisitDurationMinutes = 0.0,
  });

  Map<String, double> calculateBreakdown() {
    // 1. KM Distance Score (15% Weight)
    // Target: 25+ KM for full score
    double kmScore = (totalKm / 25.0 * 15.0).clamp(0.0, 15.0);

    // 2. Visits Completed Score (20% Weight)
    // Target: 10+ visits for full score
    double visitsScore = (totalVisits / 10.0 * 20.0).clamp(0.0, 20.0);

    // 3. Punctuality Score (15% Weight)
    // Target: start duty by 9:00 AM. Deduct 2 points per 15 mins late.
    double punctualityScore = 15.0;
    if (dutyStartTime != null) {
      final targetTime = DateTime(dutyStartTime!.year, dutyStartTime!.month, dutyStartTime!.day, 9, 0);
      if (dutyStartTime!.isAfter(targetTime)) {
        final diffMinutes = dutyStartTime!.difference(targetTime).inMinutes;
        final intervalsLate = diffMinutes / 15.0;
        punctualityScore = (15.0 - (intervalsLate * 2.0)).clamp(0.0, 15.0);
      }
    } else {
      punctualityScore = 0.0;
    }

    // 4. Visit Duration Score (15% Weight)
    // Target: 15 to 45 mins average.
    double durationScore = 0.0;
    if (totalVisits > 0) {
      if (avgVisitDurationMinutes >= 15.0 && avgVisitDurationMinutes <= 45.0) {
        durationScore = 15.0;
      } else if (avgVisitDurationMinutes > 0.0) {
        // Deduct proportionally if too short or too long
        if (avgVisitDurationMinutes < 15.0) {
          durationScore = (avgVisitDurationMinutes / 15.0 * 15.0).clamp(0.0, 15.0);
        } else {
          durationScore = (15.0 - ((avgVisitDurationMinutes - 45.0) / 10.0)).clamp(0.0, 15.0);
        }
      }
    }

    // 5. Inactivity / Idle Ratio Score (15% Weight)
    // Target: Idle time < 25% of working hours
    double idleScore = 15.0;
    if (totalWorkingMinutes > 0) {
      final idleRatio = totalIdleMinutes / totalWorkingMinutes;
      if (idleRatio > 0.25) {
        idleScore = (15.0 - ((idleRatio - 0.25) * 20.0)).clamp(0.0, 15.0);
      }
    } else {
      idleScore = 0.0;
    }

    // 6. Photo Compliance Score (10% Weight)
    // Percentage of visits with photo uploaded
    double photoScore = totalVisits > 0 ? (photoCount / totalVisits * 10.0) : 10.0;

    // 7. GPS Compliance Score (10% Weight)
    // geofence mismatches (deduct 2.5 points per mismatch)
    double gpsScore = mismatchCount == 0 ? 10.0 : (10.0 - (mismatchCount * 2.5)).clamp(0.0, 10.0);

    return {
      'km': kmScore,
      'visits': visitsScore,
      'punctuality': punctualityScore,
      'duration': durationScore,
      'idle': idleScore,
      'photo': photoScore,
      'gps': gpsScore,
      'total': kmScore + visitsScore + punctualityScore + durationScore + idleScore + photoScore + gpsScore,
    };
  }

  int calculateScore() {
    return calculateBreakdown()['total']!.round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = calculateBreakdown();
    final score = breakdown['total']!.round().clamp(0, 100);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    Color scoreColor = score >= 80 ? AppColors.success : (score >= 60 ? Colors.orange : AppColors.error);

    return Scaffold(
      appBar: AppBar(
        title: Text('Performance Scorecard', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Score Display Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    staffName,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$score%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    score >= 80
                        ? 'EXCELLENT RATING'
                        : (score >= 60 ? 'AVERAGE PERFORMANCE' : 'IMPROVEMENT PLAN REQUIRED'),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: scoreColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Performance Criteria Breakdown',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            _ScoreMetricRow(
              title: 'Movement Distance (KM)',
              value: '${totalKm.toStringAsFixed(1)} KM',
              scoreValue: breakdown['km']!,
              maxScore: 15.0,
              icon: Icons.directions_walk_rounded,
              color: AppColors.primary,
              cardColor: cardColor,
            ),
            _ScoreMetricRow(
              title: 'Shops & Doctors Visited',
              value: '$totalVisits Completed',
              scoreValue: breakdown['visits']!,
              maxScore: 20.0,
              icon: Icons.storefront_rounded,
              color: AppColors.accent,
              cardColor: cardColor,
            ),
            _ScoreMetricRow(
              title: 'Shift Start Punctuality',
              value: dutyStartTime != null ? DateFormat('hh:mm a').format(dutyStartTime!) : 'N/A',
              scoreValue: breakdown['punctuality']!,
              maxScore: 15.0,
              icon: Icons.access_time_rounded,
              color: Colors.teal,
              cardColor: cardColor,
            ),
            _ScoreMetricRow(
              title: 'Visit Engagement Duration',
              value: '${avgVisitDurationMinutes.toStringAsFixed(1)} mins (avg)',
              scoreValue: breakdown['duration']!,
              maxScore: 15.0,
              icon: Icons.timer_rounded,
              color: Colors.blue,
              cardColor: cardColor,
            ),
            _ScoreMetricRow(
              title: 'Idle Time Ratio',
              value: '$totalIdleMinutes mins idle',
              scoreValue: breakdown['idle']!,
              maxScore: 15.0,
              icon: Icons.bedtime_rounded,
              color: Colors.orange,
              cardColor: cardColor,
            ),
            _ScoreMetricRow(
              title: 'Photo Upload Compliance',
              value: '$photoCount / $totalVisits Photos',
              scoreValue: breakdown['photo']!,
              maxScore: 10.0,
              icon: Icons.photo_camera_rounded,
              color: AppColors.success,
              cardColor: cardColor,
            ),
            _ScoreMetricRow(
              title: 'Geofence GPS Accuracy',
              value: mismatchCount == 0 ? 'No Mismatches' : '$mismatchCount Flags',
              scoreValue: breakdown['gps']!,
              maxScore: 10.0,
              icon: Icons.gps_fixed_rounded,
              color: AppColors.error,
              cardColor: cardColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreMetricRow extends StatelessWidget {
  final String title;
  final String value;
  final double scoreValue;
  final double maxScore;
  final IconData icon;
  final Color color;
  final Color cardColor;

  const _ScoreMetricRow({
    required this.title,
    required this.value,
    required this.scoreValue,
    required this.maxScore,
    required this.icon,
    required this.color,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${scoreValue.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: color),
                ),
                Text('Points', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: AppColors.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
