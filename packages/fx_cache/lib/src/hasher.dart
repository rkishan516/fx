import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Computes SHA-256 hashes of task inputs for cache keying.
///
/// Inputs include: file contents (sorted by path), target name, executor
/// command, and Dart SDK version. This ensures the cache is invalidated
/// when any relevant input changes.
class Hasher {
  static final _envPattern = RegExp(r"^env\('([^']+)'\)$");
  static final _runtimePattern = RegExp(r"^runtime\('([^']+)'\)$");

  /// Returns the SHA-256 hex digest of [input].
  static String hashString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Computes a deterministic hash of all inputs for a given task.
  ///
  /// [projectPath] — absolute path to the project root
  /// [targetName] — name of the target (e.g. "test", "analyze")
  /// [executor] — resolved executor command (e.g. "dart test")
  /// [inputPatterns] — glob-style patterns relative to [projectPath]
  ///
  /// The hash covers:
  /// - Content of each matched file (sorted by relative path for determinism)
  /// - Target name
  /// - Executor command
  /// - Dart SDK version
  /// - Environment variables via `env('VAR_NAME')` patterns
  /// - Runtime command output via `runtime('command')` patterns
  /// - External dependency versions via `{externalDependencies}` pattern
  static Future<String> hashInputs({
    required String projectPath,
    required String targetName,
    required String executor,
    required List<String> inputPatterns,
  }) async {
    final buf = BytesBuilder(copy: false);

    // Stable prefix: target + executor + sdk version
    buf.add(utf8.encode('target:$targetName\n'));
    buf.add(utf8.encode('executor:$executor\n'));
    buf.add(utf8.encode('sdk:${Platform.version}\n'));

    // Process special input patterns and collect file patterns
    final filePatterns = <String>[];
    for (final pattern in inputPatterns) {
      final envMatch = _envPattern.firstMatch(pattern);
      final runtimeMatch = _runtimePattern.firstMatch(pattern);
      if (envMatch != null) {
        final varName = envMatch.group(1)!;
        final value = Platform.environment[varName] ?? '';
        buf.add(utf8.encode('env:$varName=$value\n'));
      } else if (runtimeMatch != null) {
        final command = runtimeMatch.group(1)!;
        final output = await _runCommand(command);
        buf.add(utf8.encode('runtime:$command=$output\n'));
      } else if (pattern == '{externalDependencies}') {
        final lockContent = await _readLockFile(projectPath);
        buf.add(utf8.encode('externalDeps:$lockContent\n'));
      } else {
        filePatterns.add(pattern);
      }
    }

    // Collect and sort matched files for determinism
    final matchedFiles = <String>[];
    for (final pattern in filePatterns) {
      final files = await _resolvePattern(projectPath, pattern);
      matchedFiles.addAll(files);
    }
    matchedFiles.sort();

    // Hash each file's relative path + content
    for (final filePath in matchedFiles) {
      final relPath = p.relative(filePath, from: projectPath);
      final content = await File(filePath).readAsBytes();
      buf.add(utf8.encode('file:$relPath\n'));
      buf.add(content);
      buf.add(utf8.encode('\n'));
    }

    return sha256.convert(buf.takeBytes()).toString();
  }

  /// Resolves a glob-style pattern relative to [root].
  ///
  /// Supports `**` (recursive) and `*` (single-segment) wildcards.
  static Future<List<String>> _resolvePattern(
    String root,
    String pattern,
  ) async {
    // Normalise: strip trailing slash, handle simple recursive patterns
    final parts = pattern.split('/');
    final results = <String>[];
    await _walk(Directory(root), root, parts, 0, results);
    return results;
  }

  static Future<void> _walk(
    Directory dir,
    String root,
    List<String> parts,
    int depth,
    List<String> results,
  ) async {
    if (depth >= parts.length) return;
    if (!dir.existsSync()) return;

    final segment = parts[depth];

    if (segment == '**') {
      // Recurse into all subdirectories and continue matching remaining parts
      if (depth == parts.length - 1) {
        // ** at end: match all files recursively
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) results.add(entity.path);
        }
      } else {
        // ** followed by more parts: try matching remaining at every level
        await _walk(dir, root, parts, depth + 1, results);
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            await _walk(entity, root, parts, depth, results);
          }
        }
      }
      return;
    }

    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      if (!_matches(name, segment)) continue;

      if (depth == parts.length - 1) {
        if (entity is File) results.add(entity.path);
      } else if (entity is Directory) {
        await _walk(entity, root, parts, depth + 1, results);
      }
    }
  }

  /// Returns true if [name] matches the glob [pattern] (`*` wildcard only).
  static bool _matches(String name, String pattern) {
    if (!pattern.contains('*')) return name == pattern;
    final regex = RegExp(
      '^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$',
    );
    return regex.hasMatch(name);
  }

  /// Runs a shell command and returns its trimmed stdout.
  /// Used for `runtime('dart --version')` input patterns.
  static Future<String> _runCommand(String command) async {
    try {
      final parts = command.split(' ');
      final result = await Process.run(parts.first, parts.skip(1).toList());
      return (result.stdout as String).trim();
    } catch (_) {
      return '';
    }
  }

  /// Reads the pubspec.lock nearest to [projectPath].
  /// Walks up to find the workspace-level lock file.
  static Future<String> _readLockFile(String projectPath) async {
    var dir = projectPath;
    while (true) {
      final lockFile = File(p.join(dir, 'pubspec.lock'));
      if (lockFile.existsSync()) {
        return lockFile.readAsStringSync();
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
    return '';
  }
}
