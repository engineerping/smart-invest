// lib/features/order/data/order_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/order_model.dart';

class OrderApi {
  final ApiClient _apiClient;

  OrderApi(this._apiClient);

  Future<Order> createOrder(Map<String, dynamic> orderData) async {
    final response = await _apiClient.post(
      ApiEndpoints.orderCreate,
      body: orderData,
    );
    return Order.fromJson(response);
  }

  Future<Order> getOrder(String id) async {
    final response = await _apiClient.get(ApiEndpoints.orderDetail(id));
    return Order.fromJson(response);
  }
}