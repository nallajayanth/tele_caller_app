import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

class PerformanceScoreScreen extends StatelessWidget {
  final String staffName;
  final double totalKm;
  final int totalVisits;
  final int photoCount;
  final int mismatchCount;

  const PerformanceScoreScreen({
    super.key,
    required this.staffName,
    required this.totalKm,
    required this.totalVisits,
    required this.photoCount,
    required this.mismatchCount,
  });

  int calculateScore() {
    double kmScore = (totalKm / 30.0 * 25).clamp(0.0, 25.0);
    double visitsScore = (totalVisits / 10.0 * 35).clamp(0.0, 35.0);
    double photoScore = totalVisits > 0 ? (photoCount / totalVisits * 20.0) : 20.0;
    double gpsScore = mismatchCount == 0 ? 20.0 : (20.0 - (mismatchCount * 5)).clamp(0.0, 20.0);

    return (kmScore + visitsScore + photoScore + gpsScore).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final score = calculateScore();
    Color scoreColor = score >= 80 ? AppColors.success : (score >= 60 ? Colors.orange : AppColors.error);

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Performance Score', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: scoreColor, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    staffName,
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$score%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    score >= 80 ? 'EXCELLENT PERFORMANCE' : (score >= 60 ? 'AVERAGE PERFORMANCE' : 'NEEDS IMPROVEMENT'),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _ScoreMetricRow(title: 'KM Distance Traveled', value: '${totalKm.toStringAsFixed(1)} KM', weight: '25% Weight'),
            _ScoreMetricRow(title: 'Field Visits Completed', value: '$totalVisits Visits', weight: '35% Weight'),
            _ScoreMetricRow(title: 'Photo Proof Uploaded', value: '$photoCount / $totalVisits', weight: '20% Weight'),
            _ScoreMetricRow(title: 'GPS Geofence Compliance', value: mismatchCount == 0 ? '100% Match' : '$mismatchCount Flags', weight: '20% Weight'),
          ],
        ),
      ),
    );
  }
}

class _ScoreMetricRow extends StatelessWidget {
  final String title;
  final String value;
  final String weight;

  const _ScoreMetricRow({required this.title, required this.value, required this.weight});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              Text(weight, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
            ],
          ),
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
