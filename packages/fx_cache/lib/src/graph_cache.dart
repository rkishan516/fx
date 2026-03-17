import 'dart:convert';
import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:path/path.dart' as p;

/// Abstraction over git operations used by [GraphCache].
///
/// Allows injection of a fake implementation in tests.
abstract class GitRunner {
  /// Returns the current HEAD commit hash, or null if not a git repo.
  Future<String?> currentHash(String workspaceRoot);

  /// Returns files changed since [baseHash] (relative paths from workspace root).
  Future<List<String>> changedFilesSince(String workspaceRoot, String baseHash);
}

/// Default [GitRunner] that shells out to the real `git` command.
class ProcessGitRunner implements GitRunner {
  const ProcessGitRunner();

  @override
  Future<String?> currentHash(String workspaceRoot) async {
    try {
      final result = await Process.run('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: workspaceRoot);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> changedFilesSince(
    String workspaceRoot,
    String baseHash,
  ) async {
    try {
      final result = await Process.run('git', [
        'diff',
        '--name-only',
        baseHash,
        'HEAD',
      ], workingDirectory: workspaceRoot);
      if (result.exitCode != 0) return [];
      return (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// A deserialized graph cache snapshot.
class GraphCacheSnapshot {
  final List<Project> projects;
  final ProjectGraph graph;
  final String? gitHash;
  final DateTime savedAt;

  const GraphCacheSnapshot({
    required this.projects,
    required this.graph,
    required this.gitHash,
    required this.savedAt,
  });
}

/// Persists and restores [ProjectGraph] data for incremental rebuilds.
///
/// Uses git commit hash as the primary change-detection signal. Falls back to
/// file modification timestamps for directories that are not git repositories.
///
/// Cache format (JSON):
/// ```json
/// {
///   "gitHash": "abc123",
///   "savedAt": "2026-01-01T00:00:00.000Z",
///   "projects": [...]
/// }
/// ```
class GraphCache {
  final File cacheFile;
  final GitRunner _gitRunner;

  GraphCache({required this.cacheFile, GitRunner? gitRunner})
    : _gitRunner = gitRunner ?? const ProcessGitRunner();

  /// Persist [projects] and [graph] to the cache file.
  ///
  /// [gitHash] may be null for non-git repos.
  Future<void> save({
    required List<Project> projects,
    required ProjectGraph graph,
    required String? gitHash,
  }) async {
    await cacheFile.parent.create(recursive: true);
    final data = {
      'gitHash': gitHash,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'projects': projects.map((p) => p.toJson()).toList(),
    };
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  /// Load the cache snapshot. Returns null if no cache file exists or if
  /// the file is corrupted.
  Future<GraphCacheSnapshot?> load() async {
    if (!cacheFile.existsSync()) return null;
    try {
      final data =
          jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      final projectsList = (data['projects'] as List)
          .cast<Map<String, dynamic>>()
          .map(Project.fromJson)
          .toList();
      final graph = ProjectGraph.build(projectsList);
      return GraphCacheSnapshot(
        projects: projectsList,
        graph: graph,
        gitHash: data['gitHash'] as String?,
        savedAt: DateTime.parse(data['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the git hash stored in the cache, or null if no cache exists.
  Future<String?> cachedGitHash() async {
    if (!cacheFile.existsSync()) return null;
    try {
      final data =
          jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      return data['gitHash'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns the names of projects that contain changed files since the last
  /// cache save.
  ///
  /// - If no cache exists, all projects are considered changed.
  /// - If in a git repo, uses `git diff` against [cachedGitHash].
  /// - If not a git repo (or git fails), uses file modification timestamps.
  Future<List<String>> changedPackages({
    required List<Project> projects,
    required String workspaceRoot,
  }) async {
    if (!cacheFile.existsSync()) {
      return projects.map((p) => p.name).toList();
    }

    final storedHash = await cachedGitHash();
    final currentHash = await _gitRunner.currentHash(workspaceRoot);

    if (currentHash != null && storedHash != null) {
      // Git-based change detection
      if (currentHash == storedHash) return [];
      final changedFiles = await _gitRunner.changedFilesSince(
        workspaceRoot,
        storedHash,
      );
      return _projectsContainingFiles(projects, changedFiles, workspaceRoot);
    }

    // Timestamp-based fallback for non-git repos
    return await _changedPackagesByTimestamp(projects, workspaceRoot);
  }

  /// Returns project names that contain files in [changedFiles].
  List<String> _projectsContainingFiles(
    List<Project> projects,
    List<String> changedFiles,
    String workspaceRoot,
  ) {
    final changed = <String>{};
    for (final relPath in changedFiles) {
      final absPath = p.join(workspaceRoot, relPath);
      for (final project in projects) {
        if (p.isWithin(project.path, absPath) ||
            absPath.startsWith(project.path)) {
          changed.add(project.name);
          break;
        }
      }
    }
    return changed.toList();
  }

  /// Falls back to file modification timestamps when git is unavailable.
  Future<List<String>> _changedPackagesByTimestamp(
    List<Project> projects,
    String workspaceRoot,
  ) async {
    final snapshot = await load();
    if (snapshot == null) return projects.map((p) => p.name).toList();

    final since = snapshot.savedAt;
    final changed = <String>[];

    for (final project in projects) {
      final dir = Directory(project.path);
      if (!dir.existsSync()) continue;
      var isChanged = false;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final stat = entity.statSync();
          if (stat.modified.isAfter(since)) {
            isChanged = true;
            break;
          }
        }
      }
      if (isChanged) changed.add(project.name);
    }

    return changed;
  }
}
