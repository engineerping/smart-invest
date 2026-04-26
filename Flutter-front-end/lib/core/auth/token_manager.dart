// lib/core/auth/token_manager.dart
import '../storage/secure_storage.dart';

class TokenManager {
  final SecureStorage _storage;

  TokenManager(this._storage);

  Future<void> saveAccessToken(String token) async {
    await _storage.write(SecureStorage.accessTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(SecureStorage.accessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(SecureStorage.refreshTokenKey, token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(SecureStorage.refreshTokenKey);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(SecureStorage.userIdKey, userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(SecureStorage.userIdKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
