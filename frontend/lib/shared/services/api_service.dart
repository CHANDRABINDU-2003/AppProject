import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agripulse/config.dart';

/// Low-level HTTP client for the AgriPulse backend.
///
/// Handles: base URL, JSON encoding, attaching the JWT `Authorization` header,
/// and turning non-2xx responses into [ApiException]. Every screen/service
/// goes through this one class.
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  String? _token;

  // ─────────── token persistence ───────────
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString("token");
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove("token");
    } else {
      await prefs.setString("token", token);
    }
  }

  bool get isLoggedIn => _token != null;

  Map<String, String> _headers({bool json = true}) => {
        if (json) "Content-Type": "application/json",
        if (_token != null) "Authorization": "Bearer $_token",
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse(
        "${AppConfig.apiBaseUrl}$path",
      ).replace(queryParameters: query?.map((k, v) => MapEntry(k, "$v")));

  dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final detail = (body is Map && body["detail"] != null)
        ? body["detail"].toString()
        : "Request failed (${r.statusCode})";
    throw ApiException(detail, r.statusCode);
  }

  // ─────────── generic verbs ───────────
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async =>
      _decode(await http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async => _decode(
        await http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})),
      );

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async => _decode(
        await http.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})),
      );

  Future<dynamic> delete(String path) async =>
      _decode(await http.delete(_uri(path), headers: _headers()));

  /// Login uses form-encoding (OAuth2PasswordRequestForm), not JSON.
  Future<dynamic> postForm(String path, Map<String, String> form) async => _decode(
        await http.post(_uri(path),
            headers: {"Content-Type": "application/x-www-form-urlencoded"}, body: form),
      );

  /// Multipart upload from in-memory bytes (works on web, mobile and desktop).
  ///
  /// We send bytes rather than a file path because `MultipartFile.fromPath`
  /// relies on `dart:io`, which isn't available on Flutter web.
  Future<dynamic> uploadBytes(
    String path,
    String field,
    Uint8List bytes, {
    String filename = "upload.jpg",
  }) async {
    final req = http.MultipartRequest("POST", _uri(path))
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    final streamed = await req.send();
    return _decode(await http.Response.fromStream(streamed));
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
