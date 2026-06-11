import 'package:hive_flutter/hive_flutter.dart';

class DeletedLogModel {
  final String id;
  final DateTime deletedAt;
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

  const DeletedLogModel({
    required this.id,
    required this.deletedAt,
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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deleted_at': deletedAt.toIso8601String(),
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
    };
  }

  factory DeletedLogModel.fromJson(Map<String, dynamic> json) {
    return DeletedLogModel(
      id: json['id'] as String,
      deletedAt: DateTime.parse(json['deleted_at'] as String),
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
    );
  }
}

class DeletedLogModelAdapter extends TypeAdapter<DeletedLogModel> {
  @override
  final int typeId = 1;

  @override
  DeletedLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeletedLogModel(
      id: fields[0] as String,
      deletedAt: fields[1] as DateTime,
      date: fields[2] as DateTime,
      customerName: fields[3] as String,
      mobile: fields[4] as String,
      place: fields[5] as String,
      product: fields[6] as String,
      connectedStatus: fields[7] as String,
      customerResponse: fields[8] as String,
      nextFollowUpDate: fields[9] as DateTime,
      orderValue: (fields[10] as num).toDouble(),
      remarks: fields[11] as String,
      deviceId: (fields[12] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, DeletedLogModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.deletedAt)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.mobile)
      ..writeByte(5)
      ..write(obj.place)
      ..writeByte(6)
      ..write(obj.product)
      ..writeByte(7)
      ..write(obj.connectedStatus)
      ..writeByte(8)
      ..write(obj.customerResponse)
      ..writeByte(9)
      ..write(obj.nextFollowUpDate)
      ..writeByte(10)
      ..write(obj.orderValue)
      ..writeByte(11)
      ..write(obj.remarks)
      ..writeByte(12)
      ..write(obj.deviceId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeletedLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
