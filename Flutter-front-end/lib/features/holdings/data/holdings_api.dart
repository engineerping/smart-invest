// lib/features/holdings/data/holdings_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/holding_model.dart';

class HoldingsApi {
  final ApiClient _apiClient;

  HoldingsApi(this._apiClient);

  Future<List<Holding>> getHoldings() async {
    final response = await _apiClient.get(ApiEndpoints.holdings);
    return (response as List).map((e) => Holding.fromJson(e)).toList();
  }

  Future<List<Order>> getOrders() async {
    final response = await _apiClient.get('/api/orders');
    final data = response as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    return content.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }
}