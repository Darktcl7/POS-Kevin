import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  String? _token;

  String? get token => _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    return _parse(response);
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _headers).timeout(const Duration(seconds: 10));
    return _parse(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _headers).timeout(const Duration(seconds: 10));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('GET $path failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    return _parse(response);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    return _parse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers).timeout(const Duration(seconds: 10));
    return _parse(response);
  }

  Future<Map<String, dynamic>> multipartRequest(
    String path,
    String method,
    Map<String, String> fields,
    String? filePath,
    String fileField,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest(method, uri);
    
    // Add auth header but NOT content-type (MultipartRequest sets it automatically)
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token!';
    }
    request.headers['Accept'] = 'application/json';
    
    request.fields.addAll(fields);
    
    if (filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }
    
    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    return _parse(response);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Map<String, dynamic> _parse(http.Response response) {
    final dynamic data = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data is Map<String, dynamic> ? data : <String, dynamic>{'data': data};
    }
    throw Exception('Request failed: ${response.statusCode} ${response.body}');
  }
}
