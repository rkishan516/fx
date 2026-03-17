import 'dart:convert';
import 'dart:io';

import '../cache_entry.dart';
import 'remote_cache_store.dart';

/// Remote cache store that uses an S3-compatible API.
///
/// Supports AWS S3, MinIO, DigitalOcean Spaces, and other S3-compatible
/// storage services. Authentication via access key and secret key.
class S3RemoteCacheStore implements RemoteCacheStore {
  final String bucket;
  final String region;
  final String prefix;
  final String accessKey;
  final String secretKey;
  final String endpoint;
  final HttpClient _client;

  S3RemoteCacheStore({
    required this.bucket,
    this.region = 'us-east-1',
    this.prefix = '',
    this.accessKey = '',
    this.secretKey = '',
    String? endpoint,
    HttpClient? client,
  }) : endpoint = endpoint ?? 'https://$bucket.s3.$region.amazonaws.com',
       _client = client ?? HttpClient();

  String _objectPath(String hash) {
    final pfx = prefix.isNotEmpty ? '$prefix/' : '';
    return '$pfx$hash.json';
  }

  @override
  Future<CacheEntry?> get(String hash) async {
    try {
      final path = _objectPath(hash);
      final uri = Uri.parse('$endpoint/$path');
      final request = await _client.getUrl(uri);
      _addAuth(request, 'GET', path);
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
      final path = _objectPath(hash);
      final uri = Uri.parse('$endpoint/$path');
      final request = await _client.putUrl(uri);
      _addAuth(request, 'PUT', path);
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
      final path = _objectPath(hash);
      final uri = Uri.parse('$endpoint/$path');
      final request = await _client.headUrl(uri);
      _addAuth(request, 'HEAD', path);
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
      _addAuth(request, 'DELETE', '');
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Silent failure
    }
  }

  void _addAuth(HttpClientRequest request, String method, String path) {
    if (accessKey.isNotEmpty) {
      // Simplified auth header — production use should implement AWS Sig V4
      request.headers.set('Authorization', 'AWS $accessKey:$secretKey');
    }
    request.headers.set('x-amz-content-sha256', 'UNSIGNED-PAYLOAD');
  }
}
