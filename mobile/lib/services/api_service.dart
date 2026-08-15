import 'dart:convert';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:async';

/// Thrown for non-2xx API responses. `toString()` returns just the message
/// (usually the backend's own validation text) instead of Dart's default
/// "Exception: ..." wrapping, so it's safe to show directly in the UI.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  /// The decoded JSON response body, if any — lets callers inspect
  /// structured fields (e.g. `{"email_not_verified": true}`) beyond the
  /// flattened [message].
  final dynamic body;
  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => message;
}

class ApiService {
  // Override at build/run time, e.g.:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api        (Android emulator)
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000/api    (physical device on same LAN)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  /// Server root without the trailing `/api` — used for links that point
  /// at server-rendered pages rather than JSON endpoints (e.g. Django Admin).
  static String get webBaseUrl => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  static const Duration timeout = Duration(seconds: 15); // 15 second timeout

  /// File uploads (multipart) legitimately take longer than a JSON round
  /// trip — give them more room so they don't spuriously time out while the
  /// server is still saving the file.
  static const Duration uploadTimeout = Duration(seconds: 30);

  Future<Map<String, String>> _getHeaders() async {
    // getIdToken() returns the cached token and transparently refreshes it
    // in the background when it's close to expiring — no manual refresh
    // logic needed here.
    final token = await fb.FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Extracts a human-readable message from a DRF error response body.
  /// Handles `{"detail": "..."}`, `{"error": "..."}`, and field-error shapes
  /// like `{"email": ["user with this email already exists."]}`.
  ApiException _parseError(http.BaseResponse response, String rawBody) {
    try {
      final decoded = json.decode(rawBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] is String) {
          return ApiException(decoded['detail'], statusCode: response.statusCode, body: decoded);
        }
        if (decoded['error'] is String) {
          return ApiException(decoded['error'], statusCode: response.statusCode, body: decoded);
        }
        final messages = <String>[];
        decoded.forEach((key, value) {
          if (value is List) {
            messages.addAll(value.map((v) => v.toString()));
          } else if (value is String) {
            messages.add(value);
          }
        });
        if (messages.isNotEmpty) {
          return ApiException(messages.join(' '), statusCode: response.statusCode, body: decoded);
        }
      }
    } catch (_) {
      // Body wasn't valid JSON (e.g. an HTML 500 page) — fall through.
    }
    return ApiException('Server error (${response.statusCode}). Please try again.',
        statusCode: response.statusCode);
  }

  Future<dynamic> get(String endpoint) async {
    final url = '$baseUrl$endpoint';
    log('📤 GET: $url');

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      log('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded;
      }

      throw _parseError(response, response.body);
    } on TimeoutException {
      log('⏰ Request timed out');
      throw Exception('Connection timeout. Please check your network.');
    } catch (e) {
      log('❌ Error: $e');
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, dynamic data) async {
    final url = '$baseUrl$endpoint';
    log('📤 POST: $url');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: json.encode(data),
          )
          .timeout(timeout);

      log('📥 Status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
      throw _parseError(response, response.body);
    } on TimeoutException {
      log('⏰ Request timed out');
      throw Exception('Connection timeout. Please check your network.');
    } catch (e) {
      log('❌ Error: $e');
      rethrow;
    }
  }

  /// Sends a multipart/form-data POST. [fields] are sent as form fields and
  /// [fileBytes] (when provided) is attached under [fileField] so the server
  /// receives an actual file upload instead of a URL.
  Future<dynamic> postMultipart(
    String endpoint,
    Map<String, String> fields, {
    String? fileField,
    List<int>? fileBytes,
    String? filename,
    MediaType? fileContentType,
  }) async {
    final url = '$baseUrl$endpoint';
    log('📤 POST (multipart): $url');

    try {
      final token = await fb.FirebaseAuth.instance.currentUser?.getIdToken();
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields.addAll(fields);
      if (fileField != null && fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: filename,
          contentType: fileContentType,
        ));
      }

      final streamedResponse = await request.send().timeout(uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      log('📥 Status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw _parseError(response, response.body);
    } on TimeoutException {
      log('⏰ Request timed out');
      throw Exception('Connection timeout. Please check your network.');
    } catch (e) {
      log('❌ Error: $e');
      rethrow;
    }
  }

  Future<dynamic> put(String endpoint, dynamic data) async {
    final url = '$baseUrl$endpoint';

    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: json.encode(data),
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw _parseError(response, response.body);
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your network.');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    final url = '$baseUrl$endpoint';

    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: await _getHeaders(),
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw _parseError(response, response.body);
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your network.');
    }
  }

  Future<dynamic> deleteWithBody(String endpoint, dynamic data) async {
    final url = '$baseUrl$endpoint';

    try {
      final request = http.Request('DELETE', Uri.parse(url));
      request.headers.addAll(await _getHeaders());
      request.body = json.encode(data);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw _parseError(response, response.body);
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your network.');
    }
  }
}
