class OrderModel {
  final String id;
  final String callLogId;
  final String customerName;
  final String product;
  final double orderValue;
  final String status; // 'received', 'packed', 'dispatched'
  final String? packedPhotoUrl;
  final String? dispatchedPhotoUrl;
  final String? logisticsProvider;
  final String? trackingId;
  final String assignedStaffDeviceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.callLogId,
    required this.customerName,
    required this.product,
    required this.orderValue,
    required this.status,
    this.packedPhotoUrl,
    this.dispatchedPhotoUrl,
    this.logisticsProvider,
    this.trackingId,
    required this.assignedStaffDeviceId,
    required this.createdAt,
    required this.updatedAt,
  });

  OrderModel copyWith({
    String? id,
    String? callLogId,
    String? customerName,
    String? product,
    double? orderValue,
    String? status,
    String? packedPhotoUrl,
    String? dispatchedPhotoUrl,
    String? logisticsProvider,
    String? trackingId,
    String? assignedStaffDeviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      callLogId: callLogId ?? this.callLogId,
      customerName: customerName ?? this.customerName,
      product: product ?? this.product,
      orderValue: orderValue ?? this.orderValue,
      status: status ?? this.status,
      packedPhotoUrl: packedPhotoUrl ?? this.packedPhotoUrl,
      dispatchedPhotoUrl: dispatchedPhotoUrl ?? this.dispatchedPhotoUrl,
      logisticsProvider: logisticsProvider ?? this.logisticsProvider,
      trackingId: trackingId ?? this.trackingId,
      assignedStaffDeviceId: assignedStaffDeviceId ?? this.assignedStaffDeviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_log_id': callLogId,
      'customer_name': customerName,
      'product': product,
      'order_value': orderValue,
      'status': status,
      'packed_photo_url': packedPhotoUrl,
      'dispatched_photo_url': dispatchedPhotoUrl,
      'logistics_provider': logisticsProvider,
      'tracking_id': trackingId,
      'assigned_staff_device_id': assignedStaffDeviceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      callLogId: json['call_log_id'] as String,
      customerName: json['customer_name'] as String,
      product: json['product'] as String,
      orderValue: (json['order_value'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] as String?) ?? 'received',
      packedPhotoUrl: json['packed_photo_url'] as String?,
      dispatchedPhotoUrl: json['dispatched_photo_url'] as String?,
      logisticsProvider: json['logistics_provider'] as String?,
      trackingId: json['tracking_id'] as String?,
      assignedStaffDeviceId: (json['assigned_staff_device_id'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

extension OrderModelExtensions on OrderModel {
  List<String> get packedPhotoUrls {
    if (packedPhotoUrl == null || packedPhotoUrl!.trim().isEmpty) return [];
    return packedPhotoUrl!
        .split(',')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  List<String> get dispatchedPhotoUrls {
    if (dispatchedPhotoUrl == null || dispatchedPhotoUrl!.trim().isEmpty) return [];
    return dispatchedPhotoUrl!
        .split(',')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }
}
