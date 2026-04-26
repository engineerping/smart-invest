// lib/features/auth/data/auth_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class AuthApi {
  final ApiClient _apiClient;

  AuthApi(this._apiClient);

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _apiClient.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
  }

  Future<Map<String, dynamic>> register(
      String email, String password, String name) async {
    return await _apiClient.post(
      ApiEndpoints.register,
      body: {'email': email, 'password': password, 'name': name},
      requiresAuth: false,
    );
  }

  Future<void> logout() async {
    await _apiClient.post(ApiEndpoints.logout);
  }
}