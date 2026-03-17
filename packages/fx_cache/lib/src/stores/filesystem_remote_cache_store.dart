import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../cache_entry.dart';
import 'remote_cache_store.dart';

/// A remote cache store backed by a filesystem path.
///
/// Useful for shared network drives, CI artifact directories, or local
/// testing of remote cache behaviour. Semantically identical to
/// [LocalCacheStore] but extends [RemoteCacheStore] to signal intent.
class FilesystemRemoteCacheStore extends RemoteCacheStore {
  final String remotePath;

  FilesystemRemoteCacheStore({required this.remotePath});

  File _file(String hash) => File(p.join(remotePath, '$hash.json'));

  Future<void> _ensureDir() async {
    final dir = Directory(remotePath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  @override
  Future<CacheEntry?> get(String hash) async {
    final file = _file(hash);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CacheEntry.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String hash, CacheEntry entry) async {
    await _ensureDir();
    await _file(hash).writeAsString(jsonEncode(entry.toJson()));
  }

  @override
  Future<bool> has(String hash) async => _file(hash).existsSync();

  @override
  Future<void> clear() async {
    final dir = Directory(remotePath);
    if (!dir.existsSync()) return;

    final jsonFiles = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.json'),
    );
    for (final file in jsonFiles) {
      await file.delete();
    }
  }
}
