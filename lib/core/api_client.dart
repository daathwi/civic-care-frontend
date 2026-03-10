import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiClient {
  ApiClient({String? baseUrl, this.accessToken}) : _baseUrlOverride = baseUrl;

  final String? _baseUrlOverride;

  String get baseUrl => _baseUrlOverride ?? apiBaseUrl;
  final String? accessToken;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (accessToken != null && accessToken!.isNotEmpty)
      'Authorization': 'Bearer $accessToken',
  };

  ApiClient withToken(String? token) =>
      ApiClient(baseUrl: _baseUrlOverride, accessToken: token);

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final url = _buildUrl(path, queryParameters);
    _logRequest('GET', url);
    return _withRetry(() => http.get(url, headers: _headers));
  }

  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final url = _buildUrl(path, queryParameters);
    _logRequest('POST', url, body: body);
    return _withRetry(
      () => http.post(
        url,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<ApiResponse> patch(String path, {Object? body}) async {
    final url = _buildUrl(path, null);
    _logRequest('PATCH', url, body: body);
    return _withRetry(
      () => http.patch(
        url,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Upload a file via multipart POST. Returns the parsed response.
  Future<ApiResponse> uploadFile(
    String path,
    File file, {
    String fieldName = 'file',
  }) async {
    final url = _buildUrl(path, null);
    _logRequest('UPLOAD', url, body: 'File: ${file.path}');
    try {
      final request = http.MultipartRequest('POST', url);
      if (accessToken != null && accessToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw ApiException(
          0,
          'Upload timed out. Please check your connection and try again.',
        ),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final res = _toResponse(response);
      _logResponse(url.toString(), res);
      return res;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        0,
        'Upload failed: ${e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e}',
      );
    }
  }

  Uri _buildUrl(String path, Map<String, String>? queryParameters) {
    // Avoid double slashes: if path starts with / and apiPrefix ends with / (or vice versa)
    final String cleanPrefix = apiPrefix.endsWith('/')
        ? apiPrefix.substring(0, apiPrefix.length - 1)
        : apiPrefix;
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    final String base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    var url = Uri.parse('$base$cleanPrefix$cleanPath');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      url = url.replace(queryParameters: queryParameters);
    }
    return url;
  }

  /// Retry transient failures (network, 502/503/504) up to [maxRetries].
  Future<ApiResponse> _withRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final r = await request();
        if (_isRetryable(r.statusCode) && attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 300 * attempt));
          continue;
        }
        final res = _toResponse(r);
        _logResponse(r.request?.url.toString() ?? '?', res);
        return res;
      } on SocketException {
        if (attempt >= maxRetries) {
          throw const ApiException(
            0,
            'No internet connection. Please check your network and try again.',
          );
        }
        attempt++;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } on http.ClientException {
        if (attempt >= maxRetries) {
          throw const ApiException(
            0,
            'Connection failed. Please check your network and try again.',
          );
        }
        attempt++;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  void _logRequest(String method, Uri url, {Object? body}) {
    debugPrint('--> $method $url');
    if (body != null) {
      debugPrint('Body: $body');
    }
  }

  void _logResponse(String url, ApiResponse res) {
    debugPrint('<-- [${res.statusCode}] $url');
    if (res.body != null && res.body!.length < 1000) {
      debugPrint('Resp: ${res.body}');
    }
  }

  static bool _isRetryable(int code) =>
      code == 502 || code == 503 || code == 504;

  static ApiResponse _toResponse(http.Response r) {
    return ApiResponse(
      statusCode: r.statusCode,
      body: r.body.isEmpty ? null : r.body,
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  /// Parse backend JSON error: {"detail": "..."} or {"detail": [{...}]} (422).
  factory ApiException.fromResponse(ApiResponse res) {
    final json = res.json;
    if (json is Map<String, dynamic>) {
      final detail = json['detail'];
      if (detail is String) {
        return ApiException(res.statusCode, detail);
      }
      if (detail is List) {
        return ApiValidationException(
          res.statusCode,
          detail.cast<Map<String, dynamic>>(),
        );
      }
    }
    return ApiException(
      res.statusCode,
      res.body ?? 'Request failed (${res.statusCode})',
    );
  }

  String get userMessage {
    if (statusCode == 0) return message;
    if (statusCode >= 500) return 'Server error. Please try again later.';
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 422 Unprocessable Entity with field-level errors from Pydantic.
class ApiValidationException extends ApiException {
  ApiValidationException(int statusCode, this.fieldErrors)
    : super(statusCode, 'Validation error');
  final List<Map<String, dynamic>> fieldErrors;

  /// Get the error message for a specific field name (last segment of `loc`).
  String? errorFor(String field) {
    for (final e in fieldErrors) {
      final loc = e['loc'] as List<dynamic>? ?? [];
      if (loc.isNotEmpty && loc.last.toString() == field) {
        return e['msg'] as String?;
      }
    }
    return null;
  }

  /// Human-readable summary of all field errors.
  String get summary {
    return fieldErrors
        .map((e) {
          final loc = (e['loc'] as List<dynamic>? ?? []).join(' → ');
          return '$loc: ${e['msg']}';
        })
        .join('\n');
  }

  @override
  String get userMessage =>
      summary.isNotEmpty ? summary : 'Validation error. Check your input.';
}

class ApiResponse {
  ApiResponse({required this.statusCode, this.body});

  final int statusCode;
  final String? body;

  bool get isOk => statusCode >= 200 && statusCode < 300;

  dynamic get json => body == null
      ? null
      : (() {
          try {
            return jsonDecode(body!);
          } catch (_) {
            return null;
          }
        })();
}
