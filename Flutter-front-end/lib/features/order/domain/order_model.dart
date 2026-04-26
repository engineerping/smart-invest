// lib/features/order/domain/order_model.dart
class Order {
  final String id;
  final String fundId;
  final String fundName;
  final double amount;
  final String status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.fundId,
    required this.fundName,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      fundId: json['fundId'] as String,
      fundName: json['fundName'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}