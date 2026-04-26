// lib/core/auth/auth_repository.dart
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exception.dart';
import 'token_manager.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final TokenManager _tokenManager;

  AuthRepository(this._apiClient, this._tokenManager);

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        body: {'email': email, 'password': password},
        requiresAuth: false,
      );

      final accessToken = response['accessToken'] as String;
      final refreshToken = response['refreshToken'] as String?;
      final userId = response['userId'] as String?;

      await _tokenManager.saveAccessToken(accessToken);
      if (refreshToken != null) await _tokenManager.saveRefreshToken(refreshToken);
      if (userId != null) await _tokenManager.saveUserId(userId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Login failed: $e');
    }
  }

  Future<void> register(String email, String password, String name) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.register,
        body: {'email': email, 'password': password, 'name': name},
        requiresAuth: false,
      );

      final accessToken = response['accessToken'] as String;
      final refreshToken = response['refreshToken'] as String?;
      final userId = response['userId'] as String?;

      await _tokenManager.saveAccessToken(accessToken);
      if (refreshToken != null) await _tokenManager.saveRefreshToken(refreshToken);
      if (userId != null) await _tokenManager.saveUserId(userId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Registration failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {
      // Ignore logout API errors
    } finally {
      await _tokenManager.clearAll();
    }
  }

  Future<bool> isLoggedIn() async {
    return await _tokenManager.hasValidToken();
  }
}
