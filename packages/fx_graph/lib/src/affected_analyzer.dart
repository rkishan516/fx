import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;

import 'project_graph.dart';

/// Analyzes which projects are affected by a set of changed files.
class AffectedAnalyzer {
  /// Lock file names that trigger the lockfileAffectsAll behavior.
  static const _lockFiles = {'pubspec.lock'};

  /// Compute the set of affected projects given a list of [changedFiles].
  ///
  /// A project is affected if:
  /// 1. Any changed file is within its directory, OR
  /// 2. It transitively depends on an affected project.
  ///
  /// Root-level files (outside any project) affect ALL projects, unless
  /// they are lock files and [lockfileAffectsAll] is set to `'none'`.
  ///
  /// [lockfileAffectsAll] controls lock file behavior:
  /// - `'all'` (default): lock file changes mark all projects as affected
  /// - `'none'`: lock file changes are excluded from root-level detection
  static List<Project> computeAffected({
    required List<String> changedFiles,
    required List<Project> projects,
    required ProjectGraph graph,
    required String workspaceRoot,
    String lockfileAffectsAll = 'all',
  }) {
    if (changedFiles.isEmpty) return [];

    // Separate lock files from other changed files
    final effectiveFiles = <String>[];
    final hasLockFileChanges = <String>[];

    for (final file in changedFiles) {
      final basename = p.basename(file);
      if (_lockFiles.contains(basename)) {
        hasLockFileChanges.add(file);
      } else {
        effectiveFiles.add(file);
      }
    }

    // Handle lock file changes per config
    if (hasLockFileChanges.isNotEmpty && lockfileAffectsAll != 'none') {
      // Lock file change + 'all' config → all projects affected
      return List<Project>.from(projects);
    }

    // If only lock files changed and config is 'none', use effectiveFiles
    // (which will be empty, returning no affected projects)

    // Check if any root-level files changed (conservative: affects all)
    final hasRootLevelChanges = effectiveFiles.any(
      (file) => _isRootLevelFile(file, projects, workspaceRoot),
    );

    if (hasRootLevelChanges) return List<Project>.from(projects);

    // Map changed files to directly affected projects
    final directlyAffected = <String>{};
    for (final file in effectiveFiles) {
      for (final project in projects) {
        if (_isInProject(file, project.path)) {
          directlyAffected.add(project.name);
          break;
        }
      }
    }

    // Collect all transitively affected projects
    final allAffected = <String>{...directlyAffected};
    for (final name in directlyAffected) {
      allAffected.addAll(graph.transitiveDependentsOf(name));
    }

    return projects.where((p) => allAffected.contains(p.name)).toList();
  }

  /// Whether [filePath] is within [projectPath].
  static bool _isInProject(String filePath, String projectPath) {
    final normalizedFile = p.normalize(filePath);
    final normalizedProject = p.normalize(projectPath);
    return normalizedFile.startsWith('$normalizedProject/') ||
        normalizedFile.startsWith('$normalizedProject${p.separator}');
  }

  /// Whether [filePath] is a root-level file (not inside any project).
  static bool _isRootLevelFile(
    String filePath,
    List<Project> projects,
    String workspaceRoot,
  ) {
    // If the file is not under any project, it's root-level
    for (final project in projects) {
      if (_isInProject(filePath, project.path)) return false;
    }
    // Must be within workspace root to count as root-level
    return filePath.startsWith(workspaceRoot);
  }
}
