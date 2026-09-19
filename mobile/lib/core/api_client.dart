import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.errors = const {}});

  final String message;
  final int status;
  final Map<String, List<String>> errors;

  String get firstError {
    if (errors.isEmpty) return message;
    return errors.values.first.first;
  }

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) {
    return _send(() => _client.get(_uri(path, query), headers: _headers));
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) {
    return _send(() => _client.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  }

  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? body]) {
    return _send(() => _client.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send(() => _client.delete(_uri(path), headers: _headers));
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    String? fileField,
    String? filePath,
    String? filename,
    List<({String field, String path, String? filename})>? files,
  }) {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri(path));
      req.headers['Accept'] = 'application/json';
      if (token != null && token!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }
      fields?.forEach((k, v) => req.fields[k] = v);
      if (files != null) {
        for (final f in files) {
          req.files.add(await http.MultipartFile.fromPath(f.field, f.path, filename: f.filename));
        }
      } else if (fileField != null && filePath != null) {
        req.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: filename));
      }
      final streamed = await _client.send(req);
      return http.Response.fromStream(streamed);
    });
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() run) async {
    final http.Response res;
    try {
      res = await run();
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi atau alamat API.');
    }
    if (res.body.trim().isEmpty) {
      throw ApiException('Respons server kosong (${res.statusCode})', status: res.statusCode);
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respons server tidak valid (${res.statusCode})', status: res.statusCode);
    }
    if (res.statusCode >= 400 || json['success'] == false) {
      final errors = <String, List<String>>{};
      final raw = json['errors'];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is List) {
            errors['$key'] = value.map((e) => '$e').toList();
          }
        });
      }
      throw ApiException(
        '${json['message'] ?? 'Terjadi kesalahan'}',
        status: res.statusCode,
        errors: errors,
      );
    }
    return json;
  }
}
