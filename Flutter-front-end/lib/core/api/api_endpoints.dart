// lib/core/api/api_endpoints.dart
class ApiEndpoints {
  static const String baseUrl = 'http://localhost:8080/api';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Funds
  static const String funds = '/funds';
  static String fundDetail(String id) => '/funds/$id';
  static const String multiAssetFunds = '/funds/multi-asset';

  // Portfolio
  static const String portfolio = '/portfolio';
  static const String riskAssessment = '/portfolio/risk-assessment';

  // Orders
  static const String orders = '/orders';
  static String orderDetail(String id) => '/orders/$id';
  static const String orderCreate = '/orders';

  // Holdings
  static const String holdings = '/holdings';
  static const String transactions = '/holdings/transactions';

  // Plans
  static const String plans = '/plans';
  static String planDetail(String id) => '/plans/$id';
  static const String planCreate = '/plans';
}
