// lib/features/funds/data/funds_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/fund_model.dart';

class FundsApi {
  final ApiClient _apiClient;

  FundsApi(this._apiClient);

  Future<List<Fund>> getFunds() async {
    final response = await _apiClient.get(ApiEndpoints.funds);
    return (response as List).map((e) => Fund.fromJson(e)).toList();
  }

  Future<List<Fund>> getMultiAssetFunds() async {
    final response = await _apiClient.get(ApiEndpoints.multiAssetFunds);
    return (response as List).map((e) => Fund.fromJson(e)).toList();
  }

  Future<FundDetail> getFundDetail(String id) async {
    final response = await _apiClient.get(ApiEndpoints.fundDetail(id));
    return FundDetail.fromJson(response);
  }
}