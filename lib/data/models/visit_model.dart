class VisitModel {
  final String id;
  final String staffPhone;
  final String staffName;
  final String customerName;
  final String customerType; // 'doctor', 'distributor', 'medical_shop'
  final String address;
  final DateTime arrivalTime;
  final DateTime? departureTime;
  final int visitDurationMinutes;
  final double arrivalLat;
  final double arrivalLng;
  final double? targetLat;
  final double? targetLng;
  final String? photoUrl;
  final String? photoTimestamp;
  final String remarks;
  final String? nextFollowUpDate;
  final bool isLocationMismatch; // true if distance > 100 meters

  const VisitModel({
    required this.id,
    required this.staffPhone,
    required this.staffName,
    required this.customerName,
    required this.customerType,
    required this.address,
    required this.arrivalTime,
    this.departureTime,
    this.visitDurationMinutes = 0,
    required this.arrivalLat,
    required this.arrivalLng,
    this.targetLat,
    this.targetLng,
    this.photoUrl,
    this.photoTimestamp,
    required this.remarks,
    this.nextFollowUpDate,
    this.isLocationMismatch = false,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] as String,
      staffPhone: json['staff_phone'] as String,
      staffName: json['staff_name'] as String? ?? 'Staff Member',
      customerName: json['customer_name'] as String,
      customerType: json['customer_type'] as String? ?? 'doctor',
      address: json['address'] as String? ?? '',
      arrivalTime: DateTime.parse(json['arrival_time'] as String),
      departureTime: json['departure_time'] != null ? DateTime.parse(json['departure_time'] as String) : null,
      visitDurationMinutes: (json['visit_duration_minutes'] as num?)?.toInt() ?? 0,
      arrivalLat: (json['arrival_lat'] as num).toDouble(),
      arrivalLng: (json['arrival_lng'] as num).toDouble(),
      targetLat: json['target_lat'] != null ? (json['target_lat'] as num).toDouble() : null,
      targetLng: json['target_lng'] != null ? (json['target_lng'] as num).toDouble() : null,
      photoUrl: json['photo_url'] as String?,
      photoTimestamp: json['photo_timestamp'] as String?,
      remarks: json['remarks'] as String? ?? '',
      nextFollowUpDate: json['next_followup_date'] as String?,
      isLocationMismatch: json['is_location_mismatch'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_phone': staffPhone,
      'staff_name': staffName,
      'customer_name': customerName,
      'customer_type': customerType,
      'address': address,
      'arrival_time': arrivalTime.toIso8601String(),
      'departure_time': departureTime?.toIso8601String(),
      'visit_duration_minutes': visitDurationMinutes,
      'arrival_lat': arrivalLat,
      'arrival_lng': arrivalLng,
      'target_lat': targetLat,
      'target_lng': targetLng,
      'photo_url': photoUrl,
      'photo_timestamp': photoTimestamp,
      'remarks': remarks,
      'next_followup_date': nextFollowUpDate,
      'is_location_mismatch': isLocationMismatch,
    };
  }
}
