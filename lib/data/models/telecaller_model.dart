class TelecallerModel {
  final String phoneNumber;
  final String name;
  final String role; // 'admin' or 'staff'
  final String pin;
  final bool isFieldStaff;

  const TelecallerModel({
    required this.phoneNumber,
    required this.name,
    required this.role,
    required this.pin,
    this.isFieldStaff = false,
  });

  factory TelecallerModel.fromJson(Map<String, dynamic> json) {
    return TelecallerModel(
      phoneNumber: json['phone_number'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      pin: json['pin'] as String,
      isFieldStaff: json['is_field_staff'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'name': name,
      'role': role,
      'pin': pin,
      'is_field_staff': isFieldStaff,
    };
  }
}
