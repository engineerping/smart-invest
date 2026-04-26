// lib/features/portfolio/domain/portfolio_model.dart
class Portfolio {
  final String id;
  final String name;
  final double totalValue;
  final double riskScore;
  final List<PortfolioItem> items;

  const Portfolio({
    required this.id,
    required this.name,
    required this.totalValue,
    required this.riskScore,
    required this.items,
  });

  factory Portfolio.fromJson(Map<String, dynamic> json) {
    return Portfolio(
      id: json['id'] as String,
      name: json['name'] as String,
      totalValue: (json['totalValue'] as num).toDouble(),
      riskScore: (json['riskScore'] as num).toDouble(),
      items: (json['items'] as List)
          .map((e) => PortfolioItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PortfolioItem {
  final String fundId;
  final String fundName;
  final double value;
  final double percentage;

  const PortfolioItem({
    required this.fundId,
    required this.fundName,
    required this.value,
    required this.percentage,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      fundId: json['fundId'] as String,
      fundName: json['fundName'] as String,
      value: (json['value'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}