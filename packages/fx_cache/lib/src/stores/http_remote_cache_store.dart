import 'dart:convert';
import 'dart:io';

import '../cache_entry.dart';
import 'remote_cache_store.dart';

/// Remote cache store that communicates with an HTTP cache server.
///
/// The server is expected to expose:
///   GET  /cache/:hash  — Returns JSON CacheEntry or 404
///   PUT  /cache/:hash  — Stores a JSON CacheEntry
///   HEAD /cache/:hash  — Returns 200 if exists, 404 if not
///   DELETE /cache       — Clears all entries
class HttpRemoteCacheStore implements RemoteCacheStore {
  final String baseUrl;
  final HttpClient _client;
  final Map<String, String> headers;

  HttpRemoteCacheStore({
    required this.baseUrl,
    this.headers = const {},
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  @override
  Future<CacheEntry?> get(String hash) async {
    try {
      final uri = Uri.parse('$baseUrl/cache/$hash');
      final request = await _client.getUrl(uri);
      _addHeaders(request);
      final response = await request.close();

      if (response.statusCode == 404) {
        await response.drain<void>();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return CacheEntry.fromJson(json);
    } catch (_) {
      return null; // Network errors should not break the build
    }
  }

  @override
  Future<void> put(String hash, CacheEntry entry) async {
    try {
      final uri = Uri.parse('$baseUrl/cache/$hash');
      final request = await _client.putUrl(uri);
      _addHeaders(request);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(entry.toJson()));
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Silent failure — remote cache is best-effort
    }
  }

  @override
  Future<bool> has(String hash) async {
    try {
      final uri = Uri.parse('$baseUrl/cache/$hash');
      final request = await _client.headUrl(uri);
      _addHeaders(request);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final uri = Uri.parse('$baseUrl/cache');
      final request = await _client.deleteUrl(uri);
      _addHeaders(request);
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Silent failure
    }
  }

  void _addHeaders(HttpClientRequest request) {
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }
}
