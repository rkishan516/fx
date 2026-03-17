import 'package:fx_core/fx_core.dart';

/// Resolves the execution order of targets for a given target request.
///
/// Handles `dependsOn` chains within the workspace config.
/// Supports `^` prefix for transitive dependency targets
/// (e.g., `^build` means "run build on all deps first").
/// Supports wildcard patterns (e.g., `build-*`, `*build*`).
class TaskPipeline {
  /// Resolve the execution pipeline for [targetName] in [config].
  ///
  /// Returns an ordered list of target names, with prerequisites before
  /// the requested target (e.g., `['build', 'test']` when test dependsOn build).
  ///
  /// Entries prefixed with `^` are returned as-is — the TaskRunner handles
  /// expanding them to run on dependency projects.
  ///
  /// Throws [StateError] if a circular dependency is detected.
  static List<String> resolve(String targetName, FxConfig config) {
    final visited = <String>{};
    final result = <String>[];
    final inProgress = <String>{};

    void visit(String name) {
      // Strip ^ prefix for resolution — it's handled by TaskRunner
      final cleanName = name.startsWith('^') ? name.substring(1) : name;

      if (visited.contains(name)) return;
      if (inProgress.contains(cleanName)) {
        throw StateError(
          'Circular pipeline dependency detected involving target "$cleanName". '
          'Check your dependsOn configuration.',
        );
      }

      inProgress.add(cleanName);

      final target = config.targets[cleanName];
      if (target != null) {
        for (final dep in target.dependsOn) {
          // Expand wildcard patterns against known targets
          if (_isWildcard(dep)) {
            for (final expanded in _expandWildcard(dep, config)) {
              visit(expanded);
            }
          } else {
            visit(dep);
          }
        }
      }

      inProgress.remove(cleanName);
      visited.add(name);
      result.add(name);
    }

    visit(targetName);
    return result;
  }

  /// Resolve the pipeline, returning [DependsOnEntry] objects that preserve
  /// parameter forwarding info.
  static List<DependsOnEntry> resolveEntries(
    String targetName,
    FxConfig config,
  ) {
    final visited = <String>{};
    final result = <DependsOnEntry>[];
    final inProgress = <String>{};

    void visit(DependsOnEntry entry) {
      final name = entry.target;
      final cleanName = name.startsWith('^') ? name.substring(1) : name;

      if (visited.contains(name)) return;
      if (inProgress.contains(cleanName)) {
        throw StateError(
          'Circular pipeline dependency detected involving target "$cleanName".',
        );
      }

      inProgress.add(cleanName);

      final target = config.targets[cleanName];
      if (target != null) {
        for (final dep in target.dependsOnEntries) {
          if (_isWildcard(dep.target)) {
            for (final expanded in _expandWildcard(dep.target, config)) {
              visit(
                DependsOnEntry(
                  target: expanded,
                  projects: dep.projects,
                  params: dep.params,
                ),
              );
            }
          } else {
            visit(dep);
          }
        }
      }

      inProgress.remove(cleanName);
      visited.add(name);
      result.add(entry);
    }

    visit(DependsOnEntry(target: targetName));
    return result;
  }

  /// Returns true if the entry is a transitive dependency target (^prefix).
  static bool isTransitive(String entry) => entry.startsWith('^');

  /// Strips the ^ prefix from a target name.
  static String stripPrefix(String entry) =>
      entry.startsWith('^') ? entry.substring(1) : entry;

  /// Whether a target name contains wildcard characters.
  static bool _isWildcard(String name) {
    final clean = name.startsWith('^') ? name.substring(1) : name;
    return clean.contains('*');
  }

  /// Expand a wildcard pattern against known target names in config.
  static List<String> _expandWildcard(String pattern, FxConfig config) {
    final hasCaretPrefix = pattern.startsWith('^');
    final clean = hasCaretPrefix ? pattern.substring(1) : pattern;
    final regex = RegExp('^${RegExp.escape(clean).replaceAll(r'\*', '.*')}\$');

    final matches = <String>[];
    for (final targetName in config.targets.keys) {
      if (regex.hasMatch(targetName)) {
        matches.add(hasCaretPrefix ? '^$targetName' : targetName);
      }
    }
    return matches;
  }
}
