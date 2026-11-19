import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl = (baseUrl ?? _configuredBaseUrl()).replaceFirst(
        RegExp(r'/+$'),
        '',
      ),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? accessToken;

  static String _configuredBaseUrl() {
    final configured = dotenv.isInitialized
        ? dotenv.env['API_BASE_URL']?.trim()
        : null;
    if (configured != null && configured.isNotEmpty) return configured;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$baseUrl/$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated && accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      final streamedResponse = await _client.send(request);
      response = await http.Response.fromStream(streamedResponse);
    } on http.ClientException catch (error) {
      throw ApiException(
        0,
        'Cannot reach the MovieTracker API at $baseUrl. Start the backend '
        'with "npm start" from the backend folder, then check API_BASE_URL '
        'and the backend CORS_ORIGINS setting. Details: ${error.message}',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Request failed (${response.statusCode}).';
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic> && payload['error'] is String) {
          message = payload['error'] as String;
        }
      } on FormatException {
        // Keep the status-based message for non-JSON responses.
      }
      throw ApiException(response.statusCode, message);
    }
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The API returned an invalid response.');
    }
    return decoded;
  }

  void close() => _client.close();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});
