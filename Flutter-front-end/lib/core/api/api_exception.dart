// lib/core/api/api_exception.dart
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';

  factory ApiException.unauthorized() =>
      ApiException(401, 'Unauthorized - Please login again');

  factory ApiException.notFound() =>
      ApiException(404, 'Resource not found');

  factory ApiException.serverError() =>
      ApiException(500, 'Server error - Please try again later');

  factory ApiException.networkError() =>
      ApiException(0, 'Network error - Please check your connection');
}
