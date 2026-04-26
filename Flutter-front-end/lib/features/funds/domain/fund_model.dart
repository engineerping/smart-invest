// lib/features/funds/domain/fund_model.dart
class Fund {
  final String id;
  final String code;
  final String name;
  final String fundType;
  final int riskLevel;
  final double currentNav;
  final String navDate;
  final double annualMgmtFee;
  final double minInvestment;
  final String? benchmarkIndex;
  final String? marketFocus;
  final String? description;

  const Fund({
    required this.id,
    required this.code,
    required this.name,
    required this.fundType,
    required this.riskLevel,
    required this.currentNav,
    required this.navDate,
    required this.annualMgmtFee,
    required this.minInvestment,
    this.benchmarkIndex,
    this.marketFocus,
    this.description,
  });

  factory Fund.fromJson(Map<String, dynamic> json) {
    return Fund(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String,
      fundType: json['fundType'] as String? ?? '',
      riskLevel: json['riskLevel'] as int? ?? 1,
      currentNav: (json['currentNav'] as num?)?.toDouble() ?? (json['nav'] as num?)?.toDouble() ?? 0.0,
      navDate: json['navDate'] as String? ?? '',
      annualMgmtFee: (json['annualMgmtFee'] as num?)?.toDouble() ?? 0.0,
      minInvestment: (json['minInvestment'] as num?)?.toDouble() ?? 0.0,
      benchmarkIndex: json['benchmarkIndex'] as String?,
      marketFocus: json['marketFocus'] as String?,
      description: json['description'] as String?,
    );
  }
}

class FundDetail extends Fund {
  const FundDetail({
    required super.id,
    required super.code,
    required super.name,
    required super.fundType,
    required super.riskLevel,
    required super.currentNav,
    required super.navDate,
    required super.annualMgmtFee,
    required super.minInvestment,
    super.benchmarkIndex,
    super.marketFocus,
    super.description,
  });

  factory FundDetail.fromJson(Map<String, dynamic> json) {
    return FundDetail(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String,
      fundType: json['fundType'] as String? ?? '',
      riskLevel: json['riskLevel'] as int? ?? 1,
      currentNav: (json['currentNav'] as num?)?.toDouble() ?? (json['nav'] as num?)?.toDouble() ?? 0.0,
      navDate: json['navDate'] as String? ?? '',
      annualMgmtFee: (json['annualMgmtFee'] as num?)?.toDouble() ?? 0.0,
      minInvestment: (json['minInvestment'] as num?)?.toDouble() ?? 0.0,
      benchmarkIndex: json['benchmarkIndex'] as String?,
      marketFocus: json['marketFocus'] as String?,
      description: json['description'] as String?,
    );
  }
}

class TopHolding {
  final String holdingName;
  final double weight;

  const TopHolding({required this.holdingName, required this.weight});

  factory TopHolding.fromJson(Map<String, dynamic> json) {
    return TopHolding(
      holdingName: json['holdingName'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NavHistoryPoint {
  final String navDate;
  final double nav;

  const NavHistoryPoint({required this.navDate, required this.nav});

  factory NavHistoryPoint.fromJson(Map<String, dynamic> json) {
    return NavHistoryPoint(
      navDate: json['navDate'] as String? ?? '',
      nav: (json['nav'] as num?)?.toDouble() ?? 0.0,
    );
  }
}