class AttendanceModel {
  final String id;
  final String staffPhone;
  final String staffName;
  final String date; // YYYY-MM-DD
  final DateTime startTime;
  final DateTime? endTime;
  final double startLatitude;
  final double startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final int startBattery;
  final int? endBattery;
  final String startNetwork;
  final String? endNetwork;
  final String deviceId;
  final String? startSelfieUrl;
  final int totalWorkingMinutes;
  final bool isActive;

  const AttendanceModel({
    required this.id,
    required this.staffPhone,
    required this.staffName,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.startLatitude,
    required this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    required this.startBattery,
    this.endBattery,
    required this.startNetwork,
    this.endNetwork,
    required this.deviceId,
    this.startSelfieUrl,
    this.totalWorkingMinutes = 0,
    required this.isActive,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      staffPhone: json['staff_phone'] as String,
      staffName: json['staff_name'] as String,
      date: json['date'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      startLatitude: (json['start_latitude'] as num).toDouble(),
      startLongitude: (json['start_longitude'] as num).toDouble(),
      endLatitude: json['end_latitude'] != null ? (json['end_latitude'] as num).toDouble() : null,
      endLongitude: json['end_longitude'] != null ? (json['end_longitude'] as num).toDouble() : null,
      startBattery: (json['start_battery'] as num).toInt(),
      endBattery: json['end_battery'] != null ? (json['end_battery'] as num).toInt() : null,
      startNetwork: json['start_network'] as String? ?? 'Online',
      endNetwork: json['end_network'] as String?,
      deviceId: json['device_id'] as String,
      startSelfieUrl: json['start_selfie_url'] as String?,
      totalWorkingMinutes: (json['total_working_minutes'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_phone': staffPhone,
      'staff_name': staffName,
      'date': date,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'start_battery': startBattery,
      'end_battery': endBattery,
      'start_network': startNetwork,
      'end_network': endNetwork,
      'device_id': deviceId,
      'start_selfie_url': startSelfieUrl,
      'total_working_minutes': totalWorkingMinutes,
      'is_active': isActive,
    };
  }

  AttendanceModel copyWith({
    DateTime? endTime,
    double? endLatitude,
    double? endLongitude,
    int? endBattery,
    String? endNetwork,
    int? totalWorkingMinutes,
    bool? isActive,
  }) {
    return AttendanceModel(
      id: id,
      staffPhone: staffPhone,
      staffName: staffName,
      date: date,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      startBattery: startBattery,
      endBattery: endBattery ?? this.endBattery,
      startNetwork: startNetwork,
      endNetwork: endNetwork ?? this.endNetwork,
      deviceId: deviceId,
      startSelfieUrl: startSelfieUrl,
      totalWorkingMinutes: totalWorkingMinutes ?? this.totalWorkingMinutes,
      isActive: isActive ?? this.isActive,
    );
  }
}
