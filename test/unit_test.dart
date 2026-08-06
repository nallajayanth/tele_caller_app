import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telecaller_mobile_app/data/models/attendance_model.dart';
import 'package:telecaller_mobile_app/data/models/visit_model.dart';
import 'package:telecaller_mobile_app/data/models/route_point_model.dart';
import 'package:telecaller_mobile_app/presentation/admin/screens/performance_score_screen.dart';
import 'package:telecaller_mobile_app/core/utils/product_formatter.dart';

void main() {
  group('ProductFormatter Utility Tests', () {
    test('Formats JSON product string into clean product list', () {
      const rawJson = '[{"name":"test 1","qty":1},{"name":"Paracetamol","qty":2}]';
      final formatted = ProductFormatter.format(rawJson);
      expect(formatted, equals('test 1 × 1, Paracetamol × 2'));
    });

    test('Formats plain text product string as-is', () {
      const rawText = 'Amoxicillin Syrup';
      final formatted = ProductFormatter.format(rawText);
      expect(formatted, equals('Amoxicillin Syrup'));
    });
  });

  group('GPS Module Model & Serialization Tests', () {
    test('AttendanceModel JSON serialization and copyWith', () {
      final now = DateTime.now();
      final model = AttendanceModel(
        id: '9876543210_2026-08-05',
        staffPhone: '9876543210',
        staffName: 'John Field',
        date: '2026-08-05',
        startTime: now,
        startLatitude: 17.3850,
        startLongitude: 78.4867,
        startBattery: 95,
        startNetwork: '4G',
        deviceId: 'device-123',
        isActive: true,
      );

      final json = model.toJson();
      expect(json['id'], equals('9876543210_2026-08-05'));
      expect(json['staff_phone'], equals('9876543210'));
      expect(json['is_active'], isTrue);

      final deserialized = AttendanceModel.fromJson(json);
      expect(deserialized.id, equals(model.id));
      expect(deserialized.startLatitude, equals(17.3850));

      final updated = deserialized.copyWith(isActive: false, totalWorkingMinutes: 480);
      expect(updated.isActive, isFalse);
      expect(updated.totalWorkingMinutes, equals(480));
    });

    test('VisitModel JSON serialization and location mismatch check', () {
      final now = DateTime.now();
      final visit = VisitModel(
        id: 'visit_001',
        staffPhone: '9876543210',
        staffName: 'John Field',
        customerName: 'Dr. Smith Clinic',
        customerType: 'doctor',
        address: 'Banjara Hills, Hyderabad',
        arrivalTime: now,
        arrivalLat: 17.4126,
        arrivalLng: 78.4482,
        targetLat: 17.4135,
        targetLng: 78.4490,
        remarks: 'Sample given. Followup in 3 days.',
        isLocationMismatch: false,
      );

      final json = visit.toJson();
      expect(json['customer_name'], equals('Dr. Smith Clinic'));
      expect(json['is_location_mismatch'], isFalse);

      final reconstructed = VisitModel.fromJson(json);
      expect(reconstructed.customerType, equals('doctor'));
      expect(reconstructed.arrivalLat, equals(17.4126));
    });

    test('RoutePointModel JSON serialization and mock GPS flag', () {
      final point = RoutePointModel(
        latitude: 17.3850,
        longitude: 78.4867,
        timestamp: DateTime.now(),
        speed: 12.5,
        accuracy: 5.0,
        batteryLevel: 88,
        isMocked: true,
      );

      final json = point.toJson();
      expect(json['is_mocked'], isTrue);
      expect(json['speed'], equals(12.5));

      final reconstructed = RoutePointModel.fromJson(json);
      expect(reconstructed.isMocked, isTrue);
    });
  });

  group('GPS Geofence Distance Verification Engine', () {
    test('Calculates distance threshold between arrival and target correctly', () {
      // Banjara Hills Road #1 vs Banjara Hills Road #2 (~300 meters)
      final distance = Geolocator.distanceBetween(
        17.4126,
        78.4482,
        17.4150,
        78.4500,
      );

      expect(distance, greaterThan(100.0));
      bool isMismatch = distance > 100.0;
      expect(isMismatch, isTrue);
    });
  });

  group('Daily Performance Scoring Algorithm Tests', () {
    test('Calculates 100% score for full metrics completion', () {
      const widget = PerformanceScoreScreen(
        staffName: 'John Field',
        totalKm: 30.0,
        totalVisits: 10,
        photoCount: 10,
        mismatchCount: 0,
      );

      final score = widget.calculateScore();
      expect(score, equals(100));
    });

    test('Calculates partial score for partial completion', () {
      const widget = PerformanceScoreScreen(
        staffName: 'John Field',
        totalKm: 15.0, // 50% of 25 = 12.5
        totalVisits: 5, // 50% of 35 = 17.5
        photoCount: 5,  // 100% of 20 = 20.0
        mismatchCount: 1, // 15 out of 20
      );

      final score = widget.calculateScore();
      expect(score, equals(65));
    });
  });
}
