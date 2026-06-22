import 'package:hive_flutter/hive_flutter.dart';

class CallLogModel {
  final String id;
  final DateTime date;
  final String customerName;
  final String mobile;
  final String place;
  final String product;
  final String connectedStatus;
  final String customerResponse;
  final DateTime nextFollowUpDate;
  final double orderValue;
  final String remarks;
  final String deviceId;

  // New fields
  final double amountReceived;
  final double amountDue;
  final bool whatsappDone;
  final String? standardRemark;
  final String? orderStatus; // received, packed, dispatched
  final DateTime? orderStatusUpdatedAt;
  final String? clinicName;

  const CallLogModel({
    required this.id,
    required this.date,
    required this.customerName,
    required this.mobile,
    required this.place,
    required this.product,
    required this.connectedStatus,
    required this.customerResponse,
    required this.nextFollowUpDate,
    required this.orderValue,
    required this.remarks,
    required this.deviceId,
    this.amountReceived = 0.0,
    this.amountDue = 0.0,
    this.whatsappDone = false,
    this.standardRemark,
    this.orderStatus,
    this.orderStatusUpdatedAt,
    this.clinicName,
  });

  CallLogModel copyWith({
    String? id,
    DateTime? date,
    String? customerName,
    String? mobile,
    String? place,
    String? product,
    String? connectedStatus,
    String? customerResponse,
    DateTime? nextFollowUpDate,
    double? orderValue,
    String? remarks,
    String? deviceId,
    double? amountReceived,
    double? amountDue,
    bool? whatsappDone,
    String? standardRemark,
    String? orderStatus,
    DateTime? orderStatusUpdatedAt,
    String? clinicName,
  }) {
    return CallLogModel(
      id: id ?? this.id,
      date: date ?? this.date,
      customerName: customerName ?? this.customerName,
      mobile: mobile ?? this.mobile,
      place: place ?? this.place,
      product: product ?? this.product,
      connectedStatus: connectedStatus ?? this.connectedStatus,
      customerResponse: customerResponse ?? this.customerResponse,
      nextFollowUpDate: nextFollowUpDate ?? this.nextFollowUpDate,
      orderValue: orderValue ?? this.orderValue,
      remarks: remarks ?? this.remarks,
      deviceId: deviceId ?? this.deviceId,
      amountReceived: amountReceived ?? this.amountReceived,
      amountDue: amountDue ?? this.amountDue,
      whatsappDone: whatsappDone ?? this.whatsappDone,
      standardRemark: standardRemark ?? this.standardRemark,
      orderStatus: orderStatus ?? this.orderStatus,
      orderStatusUpdatedAt: orderStatusUpdatedAt ?? this.orderStatusUpdatedAt,
      clinicName: clinicName ?? this.clinicName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CallLogModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'customer_name': customerName,
      'mobile': mobile,
      'place': place,
      'product': product,
      'connected_status': connectedStatus,
      'customer_response': customerResponse,
      'next_follow_up_date': nextFollowUpDate.toIso8601String(),
      'order_value': orderValue,
      'remarks': remarks,
      'device_id': deviceId,
      'amount_received': amountReceived,
      'amount_due': amountDue,
      'whatsapp_done': whatsappDone,
      'standard_remark': standardRemark,
      'order_status': orderStatus,
      'order_status_updated_at': orderStatusUpdatedAt?.toIso8601String(),
      'clinic_name': clinicName,
    };
  }

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    return CallLogModel(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      customerName: json['customer_name'] as String,
      mobile: json['mobile'] as String,
      place: json['place'] as String,
      product: json['product'] as String,
      connectedStatus: json['connected_status'] as String,
      customerResponse: (json['customer_response'] as String?) ?? '',
      nextFollowUpDate: DateTime.parse(json['next_follow_up_date'] as String),
      orderValue: (json['order_value'] as num?)?.toDouble() ?? 0.0,
      remarks: (json['remarks'] as String?) ?? '',
      deviceId: (json['device_id'] as String?) ?? '',
      amountReceived: (json['amount_received'] as num?)?.toDouble() ?? 0.0,
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0.0,
      whatsappDone: (json['whatsapp_done'] as bool?) ?? false,
      standardRemark: json['standard_remark'] as String?,
      orderStatus: json['order_status'] as String?,
      orderStatusUpdatedAt: json['order_status_updated_at'] != null
          ? DateTime.parse(json['order_status_updated_at'] as String)
          : null,
      clinicName: json['clinic_name'] as String?,
    );
  }
}

class CallLogModelAdapter extends TypeAdapter<CallLogModel> {
  @override
  final int typeId = 0;

  @override
  CallLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CallLogModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      customerName: fields[2] as String,
      mobile: fields[3] as String,
      place: fields[4] as String,
      product: fields[5] as String,
      connectedStatus: fields[6] as String,
      customerResponse: fields[7] as String,
      nextFollowUpDate: fields[8] as DateTime,
      orderValue: (fields[9] as num).toDouble(),
      remarks: fields[10] as String,
      deviceId: (fields[11] as String?) ?? '',
      amountReceived: (fields[12] as num?)?.toDouble() ?? 0.0,
      amountDue: (fields[13] as num?)?.toDouble() ?? 0.0,
      whatsappDone: (fields[14] as bool?) ?? false,
      standardRemark: fields[15] as String?,
      orderStatus: fields[16] as String?,
      orderStatusUpdatedAt: fields[17] as DateTime?,
      clinicName: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CallLogModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.customerName)
      ..writeByte(3)
      ..write(obj.mobile)
      ..writeByte(4)
      ..write(obj.place)
      ..writeByte(5)
      ..write(obj.product)
      ..writeByte(6)
      ..write(obj.connectedStatus)
      ..writeByte(7)
      ..write(obj.customerResponse)
      ..writeByte(8)
      ..write(obj.nextFollowUpDate)
      ..writeByte(9)
      ..write(obj.orderValue)
      ..writeByte(10)
      ..write(obj.remarks)
      ..writeByte(11)
      ..write(obj.deviceId)
      ..writeByte(12)
      ..write(obj.amountReceived)
      ..writeByte(13)
      ..write(obj.amountDue)
      ..writeByte(14)
      ..write(obj.whatsappDone)
      ..writeByte(15)
      ..write(obj.standardRemark)
      ..writeByte(16)
      ..write(obj.orderStatus)
      ..writeByte(17)
      ..write(obj.orderStatusUpdatedAt)
      ..writeByte(18)
      ..write(obj.clinicName);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
