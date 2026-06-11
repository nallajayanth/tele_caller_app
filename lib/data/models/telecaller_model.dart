class TelecallerModel {
  final String phoneNumber;
  final String name;
  final String role; // 'admin' or 'staff'
  final String pin;

  const TelecallerModel({
    required this.phoneNumber,
    required this.name,
    required this.role,
    required this.pin,
  });

  factory TelecallerModel.fromJson(Map<String, dynamic> json) {
    return TelecallerModel(
      phoneNumber: json['phone_number'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      pin: json['pin'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'name': name,
      'role': role,
      'pin': pin,
    };
  }
}
