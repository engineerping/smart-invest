// lib/features/portfolio/data/portfolio_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/portfolio_model.dart';

class PortfolioApi {
  final ApiClient _apiClient;

  PortfolioApi(this._apiClient);

  Future<Portfolio> getPortfolio() async {
    final response = await _apiClient.get(ApiEndpoints.portfolio);
    return Portfolio.fromJson(response);
  }

  Future<void> riskAssessment(Map<String, dynamic> answers) async {
    await _apiClient.post(
      ApiEndpoints.riskAssessment,
      body: answers,
    );
  }
}