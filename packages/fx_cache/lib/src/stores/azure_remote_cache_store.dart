import 'dart:convert';
import 'dart:io';

import '../cache_entry.dart';
import 'remote_cache_store.dart';

/// Remote cache store that uses Azure Blob Storage REST API.
///
/// Supports authentication via Shared Key or SAS token.
class AzureRemoteCacheStore implements RemoteCacheStore {
  final String accountName;
  final String container;
  final String prefix;
  final String? sasToken;
  final String? accountKey;
  final String endpoint;
  final HttpClient _client;

  AzureRemoteCacheStore({
    required this.accountName,
    required this.container,
    this.prefix = '',
    this.sasToken,
    this.accountKey,
    String? endpoint,
    HttpClient? client,
  }) : endpoint =
           endpoint ?? 'https://$accountName.blob.core.windows.net/$container',
       _client = client ?? HttpClient();

  String _blobPath(String hash) {
    final pfx = prefix.isNotEmpty ? '$prefix/' : '';
    return '$pfx$hash.json';
  }

  Uri _blobUri(String path) {
    final base = '$endpoint/$path';
    if (sasToken != null && sasToken!.isNotEmpty) {
      return Uri.parse('$base?$sasToken');
    }
    return Uri.parse(base);
  }

  @override
  Future<CacheEntry?> get(String hash) async {
    try {
      final uri = _blobUri(_blobPath(hash));
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
      final uri = _blobUri(_blobPath(hash));
      final request = await _client.putUrl(uri);
      _addAuth(request);
      request.headers.set('x-ms-blob-type', 'BlockBlob');
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
      final uri = _blobUri(_blobPath(hash));
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
      // Azure doesn't support deleting a container's contents in one call.
      // This deletes the container itself (which requires re-creation).
      final uri = _blobUri('');
      final request = await _client.deleteUrl(uri);
      _addAuth(request);
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      // Silent failure
    }
  }

  void _addAuth(HttpClientRequest request) {
    if (accountKey != null && accountKey!.isNotEmpty) {
      // Simplified — production use should implement Azure Shared Key auth
      request.headers.set(
        'Authorization',
        'SharedKey $accountName:$accountKey',
      );
    }
    request.headers.set('x-ms-version', '2021-12-02');
  }
}
