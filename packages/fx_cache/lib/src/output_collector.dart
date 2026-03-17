import 'dart:io';

import 'package:path/path.dart' as p;

/// Collects output files matching glob patterns for cache storage,
/// and restores them from cache entries.
class OutputCollector {
  /// Collects files matching [outputPatterns] relative to [projectPath].
  /// Returns a map of relative path → file content (as string).
  static Future<Map<String, String>> collect({
    required String projectPath,
    required List<String> outputPatterns,
  }) async {
    final artifacts = <String, String>{};
    for (final pattern in outputPatterns) {
      final files = await _resolvePattern(projectPath, pattern);
      for (final filePath in files) {
        final relPath = p.relative(filePath, from: projectPath);
        try {
          artifacts[relPath] = await File(filePath).readAsString();
        } catch (_) {
          // Skip binary or unreadable files
        }
      }
    }
    return artifacts;
  }

  /// Restores output artifacts to [projectPath].
  static Future<int> restore({
    required String projectPath,
    required Map<String, String> artifacts,
  }) async {
    var count = 0;
    for (final entry in artifacts.entries) {
      final filePath = p.join(projectPath, entry.key);
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      count++;
    }
    return count;
  }

  static Future<List<String>> _resolvePattern(
    String root,
    String pattern,
  ) async {
    final dir = Directory(root);
    if (!dir.existsSync()) return [];

    // Simple glob: if pattern ends with /**, collect all files in that dir
    if (pattern.endsWith('/**')) {
      final prefix = pattern.substring(0, pattern.length - 3);
      final targetDir = Directory(p.join(root, prefix));
      if (!targetDir.existsSync()) return [];
      final results = <String>[];
      await for (final entity in targetDir.list(recursive: true)) {
        if (entity is File) results.add(entity.path);
      }
      return results;
    }

    // Direct file path
    final file = File(p.join(root, pattern));
    if (file.existsSync()) return [file.path];

    return [];
  }
}
