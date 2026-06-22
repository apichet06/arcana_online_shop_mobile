import 'package:dio/dio.dart';
import 'package:arcana_online_shop_mobile/config/app_config.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';

class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
    : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;
  final String _baseUrl;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) async {
    return _send(() {
      return _dio.get<dynamic>(
        path,
        queryParameters: _filteredQuery(queryParameters),
        options: _authOptions(),
      );
    });
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, String?> queryParameters = const {},
  }) async {
    return _send(() {
      return _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: _filteredQuery(queryParameters),
        options: _authOptions(),
      );
    });
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
    Map<String, String?> queryParameters = const {},
  }) async {
    return _send(() {
      return _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: _filteredQuery(queryParameters),
        options: _authOptions(),
      );
    });
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _send(() {
      return _dio.delete<dynamic>(path, options: _authOptions());
    });
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return _decodeResponse(await request());
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 &&
          AuthSession.instance.accessToken != null) {
        final refreshed = await AuthSession.instance.refreshAccessToken();
        if (refreshed) {
          try {
            return _decodeResponse(await request());
          } on DioException catch (retryError) {
            throw _toApiException(retryError);
          }
        }
      }

      throw _toApiException(error);
    }
  }

  Map<String, dynamic> _decodeResponse(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const FormatException('API response is not a JSON object');
  }

  Options _authOptions() {
    final token = AuthSession.instance.accessToken;
    if (token == null || token.isEmpty) return Options();

    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  ApiException _toApiException(DioException error) {
    final data = error.response?.data;
    var message = error.message ?? 'Request failed';
    if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    } else if (data != null) {
      message = data.toString();
    }

    return ApiException(
      statusCode: error.response?.statusCode ?? 0,
      message: message,
    );
  }

  String resolveAssetUrl(String? value) {
    if (value == null || value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final baseUri = Uri.parse(_baseUrl);
    final cleanPath = value.startsWith('/') ? value.substring(1) : value;

    if (cleanPath.startsWith('api/')) {
      final origin = baseUri.replace(path: '', query: '', fragment: '');
      return origin.resolve(cleanPath).toString();
    }

    final apiBase = Uri.parse(_baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/');
    return apiBase.resolve(cleanPath).toString();
  }

  Map<String, String> _filteredQuery(Map<String, String?> queryParameters) {
    final filteredQuery = <String, String>{};

    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        filteredQuery[entry.key] = value;
      }
    }

    return filteredQuery;
  }
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
