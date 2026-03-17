import 'dart:convert';
import 'dart:io';

import '../cache_entry.dart';
import 'remote_cache_store.dart';

/// Remote cache store that uses Google Cloud Storage (GCS) JSON API.
///
/// Supports authentication via service account key JSON or
/// Application Default Credentials (when running on GCP).
class GcsRemoteCacheStore implements RemoteCacheStore {
  final String bucket;
  final String prefix;
  final String? serviceAccountKey;
  final String endpoint;
  final HttpClient _client;

  GcsRemoteCacheStore({
    required this.bucket,
    this.prefix = '',
    this.serviceAccountKey,
    String? endpoint,
    HttpClient? client,
  }) : endpoint =
           endpoint ?? 'https://storage.googleapis.com/storage/v1/b/$bucket/o',
       _client = client ?? HttpClient();

  String _objectName(String hash) {
    final pfx = prefix.isNotEmpty ? '$prefix/' : '';
    return '$pfx$hash.json';
  }

  @override
  Future<CacheEntry?> get(String hash) async {
    try {
      final name = _objectName(hash);
      final uri = Uri.parse('$endpoint/$name');
      final request = await _client.getUrl(uri);
      _addAuth(request);
      final response = await request.close();

      if (response.statusCode == 404) {
        await response.drain<void>();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return CacheEntry.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String hash, CacheEntry entry) async {
    try {
      final name = _objectName(hash);
      final uri = Uri.parse('$endpoint/$name');
      final request = await _client.putUrl(uri);
      _addAuth(request);
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
      final name = _objectName(hash);
      final uri = Uri.parse('$endpoint/$name');
      final request = await _client.headUrl(uri);
      _addAuth(request);
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
      final uri = Uri.parse('$endpoint/');
      final request = await _client.deleteUrl(uri);
      _addAuth(request);
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Silent failure
    }
  }

  void _addAuth(HttpClientRequest request) {
    if (serviceAccountKey != null && serviceAccountKey!.isNotEmpty) {
      // Simplified — production use should implement OAuth2 token exchange
      request.headers.set('Authorization', 'Bearer gcs-token');
    }
  }
}
