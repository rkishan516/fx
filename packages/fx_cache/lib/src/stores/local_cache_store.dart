import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../cache_entry.dart';
import 'cache_store.dart';

/// Filesystem-based local cache store.
///
/// Entries are persisted as JSON files under [cacheDir]:
///   `<cacheDir>/<hash>.json`
///
/// When [maxSizeMB] is set, the cache is pruned after each write
/// by evicting the oldest entries (by last-modified time) until total
/// size is under the limit.
class LocalCacheStore implements CacheStore {
  final String cacheDir;
  final int? maxSizeMB;

  LocalCacheStore({required this.cacheDir, this.maxSizeMB});

  File _file(String hash) => File(p.join(cacheDir, '$hash.json'));

  Future<void> _ensureDir() async {
    final dir = Directory(cacheDir);
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
    final file = _file(hash);
    await file.writeAsString(jsonEncode(entry.toJson()));
    await _evictIfNeeded();
  }

  @override
  Future<bool> has(String hash) async => _file(hash).existsSync();

  @override
  Future<void> clear() async {
    final dir = Directory(cacheDir);
    if (!dir.existsSync()) return;

    final jsonFiles = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.json'),
    );
    for (final file in jsonFiles) {
      await file.delete();
    }
  }

  /// Evicts oldest cache entries until total size is under [maxSizeMB].
  Future<void> _evictIfNeeded() async {
    if (maxSizeMB == null) return;
    final maxBytes = maxSizeMB! * 1024 * 1024;
    final dir = Directory(cacheDir);
    if (!dir.existsSync()) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    var totalSize = 0;
    final entries = <_CacheFileInfo>[];
    for (final file in files) {
      final stat = file.statSync();
      totalSize += stat.size;
      entries.add(_CacheFileInfo(file, stat.modified, stat.size));
    }

    if (totalSize <= maxBytes) return;

    // Sort oldest first
    entries.sort((a, b) => a.modified.compareTo(b.modified));

    for (final entry in entries) {
      if (totalSize <= maxBytes) break;
      try {
        entry.file.deleteSync();
        totalSize -= entry.size;
      } catch (_) {}
    }
  }
}

class _CacheFileInfo {
  final File file;
  final DateTime modified;
  final int size;
  _CacheFileInfo(this.file, this.modified, this.size);
}
