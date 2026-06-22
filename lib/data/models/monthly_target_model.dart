class MonthlyTargetModel {
  final String id;
  final String staffDeviceId;
  final int month;
  final int year;
  final double targetAmount;
  final DateTime setAt;

  const MonthlyTargetModel({
    required this.id,
    required this.staffDeviceId,
    required this.month,
    required this.year,
    required this.targetAmount,
    required this.setAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_device_id': staffDeviceId,
      'month': month,
      'year': year,
      'target_amount': targetAmount,
      'set_at': setAt.toIso8601String(),
    };
  }

  factory MonthlyTargetModel.fromJson(Map<String, dynamic> json) {
    return MonthlyTargetModel(
      id: json['id'] as String,
      staffDeviceId: json['staff_device_id'] as String,
      month: json['month'] as int,
      year: json['year'] as int,
      targetAmount: (json['target_amount'] as num).toDouble(),
      setAt: DateTime.parse(json['set_at'] as String),
    );
  }
}
