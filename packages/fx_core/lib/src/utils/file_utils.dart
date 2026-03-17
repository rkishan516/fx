import 'dart:io';

import 'package:path/path.dart' as p;

/// File system utilities for fx.
class FileUtils {
  /// Find the workspace root by walking up from [startDir].
  ///
  /// Looks for either `fx.yaml` or `pubspec.yaml` with an `fx:` section.
  /// Returns null if no workspace root is found.
  static String? findWorkspaceRoot(String startDir) {
    var dir = Directory(startDir);
    while (true) {
      // Prefer fx.yaml
      final fxYaml = File(p.join(dir.path, 'fx.yaml'));
      if (fxYaml.existsSync()) return dir.path;

      // Fall back to pubspec.yaml with fx: section
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains('\nfx:') || content.startsWith('fx:')) {
          return dir.path;
        }
      }

      final parent = dir.parent;
      if (parent.path == dir.path) return null; // reached filesystem root
      dir = parent;
    }
  }

  /// Ensure a directory exists, creating it recursively if needed.
  static Directory ensureDir(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Read a file as string, returns null if it doesn't exist.
  static String? readFileOrNull(String path) {
    final file = File(path);
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// Write content to file, creating parent directories as needed.
  static void writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// Delete a file if it exists.
  static void deleteFile(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  /// List all files in [rootDir] matching any of [patterns].
  ///
  /// Uses simple glob expansion with `**` for recursive directories and
  /// `*` for single-level wildcards. Returns absolute file paths.
  static List<String> findFiles(String rootDir, List<String> patterns) {
    final results = <String>{};
    for (final pattern in patterns) {
      if (pattern.contains('**')) {
        // Recursive glob: walk all files and match the tail pattern
        final parts = pattern.split('**/');
        final tail = parts.last; // e.g., "*.custom"
        _walkFiles(rootDir, tail, results);
      } else {
        // Use existing single-level glob
        results.addAll(
          _expandGlob(rootDir, pattern).where((f) => File(f).existsSync()),
        );
      }
    }
    return results.toList();
  }

  /// Recursively walk [dir] collecting files matching [tail] (simple extension/name pattern).
  static void _walkFiles(String dir, String tail, Set<String> results) {
    final d = Directory(dir);
    if (!d.existsSync()) return;
    for (final entity in d.listSync(recursive: true)) {
      if (entity is File) {
        final basename = p.basename(entity.path);
        if (_matchSimple(basename, tail)) {
          results.add(entity.path);
        }
      }
    }
  }

  /// Simple pattern match: supports `*` as wildcard within a filename.
  static bool _matchSimple(String filename, String pattern) {
    if (!pattern.contains('*')) return filename == pattern;
    final parts = pattern.split('*');
    if (parts.length == 2) {
      return filename.startsWith(parts[0]) && filename.endsWith(parts[1]);
    }
    // Fallback: just check extension
    final ext = pattern.replaceAll('*', '');
    return filename.endsWith(ext);
  }

  /// List all pubspec.yaml files in [dir] matching [patterns].
  static List<String> findPubspecs(String rootDir, List<String> patterns) {
    final results = <String>[];
    for (final pattern in patterns) {
      final glob = _expandGlob(rootDir, pattern);
      results.addAll(glob);
    }
    return results;
  }

  /// Simple glob expansion: supports `*` wildcard at one directory level.
  static List<String> _expandGlob(String rootDir, String pattern) {
    final results = <String>[];
    final parts = pattern.split('/');

    if (!parts.contains('*')) {
      // No wildcard — direct path
      final path = p.join(rootDir, pattern);
      final pubspec = p.join(path, 'pubspec.yaml');
      if (File(pubspec).existsSync()) results.add(pubspec);
      return results;
    }

    // Handle patterns like "packages/*" or "apps/*"
    final wildcardIdx = parts.indexOf('*');
    final baseParts = parts.sublist(0, wildcardIdx);
    final basePath = p.joinAll([rootDir, ...baseParts]);
    final dir = Directory(basePath);
    if (!dir.existsSync()) return results;

    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        final subParts = parts.sublist(wildcardIdx + 1);
        if (subParts.isEmpty) {
          final pubspec = p.join(entity.path, 'pubspec.yaml');
          if (File(pubspec).existsSync()) results.add(pubspec);
        } else {
          // Recurse for remaining path segments after *
          final subPattern = p.joinAll(subParts);
          final subResults = _expandGlob(entity.path, subPattern);
          results.addAll(subResults);
        }
      }
    }
    return results;
  }
}
