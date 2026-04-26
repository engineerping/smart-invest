// lib/features/plans/data/plans_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/plan_model.dart';

class PlansApi {
  final ApiClient _apiClient;

  PlansApi(this._apiClient);

  Future<List<Plan>> getPlans() async {
    final response = await _apiClient.get(ApiEndpoints.plans);
    return (response as List).map((e) => Plan.fromJson(e)).toList();
  }

  Future<Plan> createPlan(Map<String, dynamic> planData) async {
    final response = await _apiClient.post(
      ApiEndpoints.planCreate,
      body: planData,
    );
    return Plan.fromJson(response);
  }
}