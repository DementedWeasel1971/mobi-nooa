import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Network harness for agent HTTP interactions.
abstract class NetworkHarness {
  Future<String> get(String url, {Map<String, String>? headers});
  Future<String> post(String url, {Map<String, String>? headers, dynamic body});
}

/// Default HTTP network harness.
class DefaultNetworkHarness implements NetworkHarness {
  final http.Client _client;

  DefaultNetworkHarness({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<String> get(String url, {Map<String, String>? headers}) async {
    final response = await _client.get(Uri.parse(url), headers: headers);
    if (response.statusCode >= 400) {
      throw Exception('HTTP GET failed (${response.statusCode}): ${response.body}');
    }
    return response.body;
  }

  @override
  Future<String> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final reqHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };
    final encodedBody = body is String ? body : jsonEncode(body);
    final response = await _client.post(
      Uri.parse(url),
      headers: reqHeaders,
      body: encodedBody,
    );
    if (response.statusCode >= 400) {
      throw Exception('HTTP POST failed (${response.statusCode}): ${response.body}');
    }
    return response.body;
  }
}
