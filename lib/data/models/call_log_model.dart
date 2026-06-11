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
    );
  }

  @override
  void write(BinaryWriter writer, CallLogModel obj) {
    writer
      ..writeByte(12)
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
      ..write(obj.deviceId);
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
