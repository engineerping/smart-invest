// lib/features/holdings/domain/holding_model.dart
class Holding {
  final String id;
  final String fundId;
  final String? fundName;
  final String? fundCode;
  final double totalUnits;
  final double totalInvested;
  final double marketValue;

  const Holding({
    required this.id,
    required this.fundId,
    this.fundName,
    this.fundCode,
    required this.totalUnits,
    required this.totalInvested,
    required this.marketValue,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      id: json['id'] as String,
      fundId: json['fundId'] as String,
      fundName: json['fundName'] as String?,
      fundCode: json['fundCode'] as String?,
      totalUnits: (json['totalUnits'] as num).toDouble(),
      totalInvested: (json['totalInvested'] as num).toDouble(),
      marketValue: (json['marketValue'] as num).toDouble(),
    );
  }
}

class Order {
  final String id;
  final String referenceNumber;
  final String? fundId;
  final String? orderType;
  final double amount;
  final String status;
  final String orderDate;
  final String? settlementDate;

  const Order({
    required this.id,
    required this.referenceNumber,
    this.fundId,
    this.orderType,
    required this.amount,
    required this.status,
    required this.orderDate,
    this.settlementDate,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      referenceNumber: json['referenceNumber'] as String,
      fundId: json['fundId'] as String?,
      orderType: json['orderType'] as String?,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      orderDate: json['orderDate'] as String,
      settlementDate: json['settlementDate'] as String?,
    );
  }
}
