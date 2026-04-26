// lib/core/api/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'api_endpoints.dart';
import '../auth/token_manager.dart';

class ApiClient {
  final http.Client _client;
  final TokenManager _tokenManager;

  ApiClient(this._tokenManager) : _client = http.Client();

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final token = await _tokenManager.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    bool requiresAuth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await _client.get(
        uri,
        headers: await _headers(requiresAuth: requiresAuth),
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError();
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
      final response = await _client.post(
        uri,
        headers: await _headers(requiresAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError();
    }
  }

  dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      case 401:
        throw ApiException.unauthorized();
      case 404:
        throw ApiException.notFound();
      case 500:
        throw ApiException.serverError();
      default:
        throw ApiException(response.statusCode, 'Unknown error');
    }
  }

  void dispose() {
    _client.close();
  }
}
