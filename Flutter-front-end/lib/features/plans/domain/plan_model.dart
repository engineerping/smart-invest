// lib/features/plans/domain/plan_model.dart
class Plan {
  final String id;
  final String referenceNumber;
  final String fundId;
  final String? fundName;
  final double? monthlyAmount;
  final String nextContributionDate;
  final String status;
  final int completedOrders;
  final double? totalInvested;

  const Plan({
    required this.id,
    required this.referenceNumber,
    required this.fundId,
    this.fundName,
    this.monthlyAmount,
    required this.nextContributionDate,
    required this.status,
    required this.completedOrders,
    this.totalInvested,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      referenceNumber: json['referenceNumber'] as String,
      fundId: json['fundId'] as String,
      fundName: json['fundName'] as String?,
      monthlyAmount: (json['monthlyAmount'] as num?)?.toDouble(),
      nextContributionDate: json['nextContributionDate'] as String? ?? '',
      status: json['status'] as String,
      completedOrders: json['completedOrders'] as int? ?? 0,
      totalInvested: (json['totalInvested'] as num?)?.toDouble(),
    );
  }
}