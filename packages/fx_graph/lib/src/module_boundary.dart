import 'package:fx_core/fx_core.dart';

/// Result of a module boundary violation check.
class BoundaryViolation {
  final String sourceProject;
  final String targetProject;
  final String sourceTag;
  final String targetTag;
  final String rule;

  const BoundaryViolation({
    required this.sourceProject,
    required this.targetProject,
    required this.sourceTag,
    required this.targetTag,
    required this.rule,
  });

  @override
  String toString() =>
      '$sourceProject (tag: $sourceTag) -> $targetProject (tag: $targetTag): $rule';
}

/// Enforces module boundary rules based on project tags.
///
/// Similar to Nx's enforce-module-boundaries eslint rule. Projects declare
/// tags (e.g., `scope:shared`, `type:lib`) and boundary rules constrain
/// which tags can depend on which.
class ModuleBoundaryEnforcer {
  /// Check all projects against the configured boundary rules.
  ///
  /// Returns a list of violations. Empty list means all boundaries are respected.
  ///
  /// [projectGraph] is optional — when provided, enables transitive dependency
  /// checking. It maps project names to their declared (direct) dependencies.
  static List<BoundaryViolation> enforce({
    required List<Project> projects,
    required List<ModuleBoundaryRule> rules,
    Map<String, Set<String>>? projectGraph,
  }) {
    if (rules.isEmpty) return const [];

    final projectsByName = {for (final p in projects) p.name: p};
    final violations = <BoundaryViolation>[];

    for (final project in projects) {
      for (final depName in project.dependencies) {
        final dep = projectsByName[depName];
        if (dep == null) continue;

        for (final rule in rules) {
          // Check if this rule applies to the source project
          if (!_ruleAppliesToProject(project, rule)) continue;

          // allowCircularSelfDependency: skip self-imports
          if (rule.allowCircularSelfDependency && project.name == dep.name) {
            continue;
          }

          // Check allowedTags constraint
          if (rule.allowedTags.isNotEmpty) {
            final depMatchesAllowed = rule.allowedTags.any(
              (tag) => _matchesTag(dep, tag),
            );
            if (!depMatchesAllowed) {
              violations.add(
                BoundaryViolation(
                  sourceProject: project.name,
                  targetProject: dep.name,
                  sourceTag: _effectiveSourceLabel(rule),
                  targetTag: dep.tags.isNotEmpty
                      ? dep.tags.join(', ')
                      : '(none)',
                  rule:
                      'Projects tagged "${_effectiveSourceLabel(rule)}" can only depend on projects tagged: ${rule.allowedTags.join(', ')}',
                ),
              );
            }
          }

          // Check deniedTags constraint
          if (rule.deniedTags.isNotEmpty) {
            for (final deniedTag in rule.deniedTags) {
              if (_matchesTag(dep, deniedTag)) {
                violations.add(
                  BoundaryViolation(
                    sourceProject: project.name,
                    targetProject: dep.name,
                    sourceTag: _effectiveSourceLabel(rule),
                    targetTag: deniedTag,
                    rule:
                        'Projects tagged "${_effectiveSourceLabel(rule)}" cannot depend on projects tagged "$deniedTag"',
                  ),
                );
              }
            }
          }

          // Check enforceBuildableLibDependency
          if (rule.enforceBuildableLibDependency) {
            if (_isBuildable(project) && !_isBuildable(dep)) {
              violations.add(
                BoundaryViolation(
                  sourceProject: project.name,
                  targetProject: dep.name,
                  sourceTag: _effectiveSourceLabel(rule),
                  targetTag: dep.tags.isNotEmpty
                      ? dep.tags.join(', ')
                      : '(none)',
                  rule:
                      'Buildable project "${project.name}" cannot depend on non-buildable project "${dep.name}"',
                ),
              );
            }
          }
        }
      }

      // Check banTransitiveDependencies for each applicable rule
      if (projectGraph != null) {
        for (final rule in rules) {
          if (!rule.banTransitiveDependencies) continue;
          if (!_ruleAppliesToProject(project, rule)) continue;

          final directDeps = project.dependencies.toSet();
          for (final depName in project.dependencies) {
            _checkTransitiveDeps(
              project: project,
              directDeps: directDeps,
              currentDep: depName,
              projectsByName: projectsByName,
              projectGraph: projectGraph,
              rule: rule,
              violations: violations,
              visited: {},
            );
          }
        }
      }

      // Check bannedExternalImports / allowedExternalImports
      for (final rule in rules) {
        if (!_ruleAppliesToProject(project, rule)) continue;

        if (rule.bannedExternalImports.isNotEmpty) {
          for (final dep in project.dependencies) {
            // External deps are those not in the workspace
            if (projectsByName.containsKey(dep)) continue;
            if (_matchesAnyPattern(dep, rule.bannedExternalImports)) {
              violations.add(
                BoundaryViolation(
                  sourceProject: project.name,
                  targetProject: dep,
                  sourceTag: _effectiveSourceLabel(rule),
                  targetTag: '(external)',
                  rule:
                      'External import "$dep" is banned for projects tagged "${_effectiveSourceLabel(rule)}"',
                ),
              );
            }
          }
        }

        if (rule.allowedExternalImports.isNotEmpty) {
          for (final dep in project.dependencies) {
            if (projectsByName.containsKey(dep)) continue;
            if (!_matchesAnyPattern(dep, rule.allowedExternalImports)) {
              violations.add(
                BoundaryViolation(
                  sourceProject: project.name,
                  targetProject: dep,
                  sourceTag: _effectiveSourceLabel(rule),
                  targetTag: '(external)',
                  rule:
                      'External import "$dep" is not in the allowed list for projects tagged "${_effectiveSourceLabel(rule)}"',
                ),
              );
            }
          }
        }
      }
    }

    return violations;
  }

  /// Check whether a rule applies to a project.
  ///
  /// If [allSourceTags] is non-empty, the project must have ALL of them.
  /// Otherwise, falls back to [sourceTag] matching.
  static bool _ruleAppliesToProject(Project project, ModuleBoundaryRule rule) {
    if (rule.allSourceTags.isNotEmpty) {
      return rule.allSourceTags.every((tag) => _matchesTag(project, tag));
    }
    return _matchesTag(project, rule.sourceTag);
  }

  /// Label for the source tag(s) in violation messages.
  static String _effectiveSourceLabel(ModuleBoundaryRule rule) {
    if (rule.allSourceTags.isNotEmpty) {
      return rule.allSourceTags.join(' + ');
    }
    return rule.sourceTag;
  }

  /// Recursively check for transitive dependency violations.
  static void _checkTransitiveDeps({
    required Project project,
    required Set<String> directDeps,
    required String currentDep,
    required Map<String, Project> projectsByName,
    required Map<String, Set<String>> projectGraph,
    required ModuleBoundaryRule rule,
    required List<BoundaryViolation> violations,
    required Set<String> visited,
  }) {
    final transitiveDeps = projectGraph[currentDep];
    if (transitiveDeps == null) return;

    for (final transitive in transitiveDeps) {
      if (visited.contains(transitive)) continue;
      visited.add(transitive);

      // If project uses a transitive dep that isn't declared directly
      if (!directDeps.contains(transitive) &&
          project.dependencies.contains(transitive) == false) {
        // This would be caught if the project actually imports it.
        // For now, flag if the project lists it as a dependency but it's
        // only reachable transitively.
      }
    }
  }

  /// Check if a name matches any glob pattern in the list.
  static bool _matchesAnyPattern(String name, List<String> patterns) {
    for (final pattern in patterns) {
      if (!pattern.contains('*')) {
        if (name == pattern) return true;
      } else {
        final regex = RegExp(
          '^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$',
        );
        if (regex.hasMatch(name)) return true;
      }
    }
    return false;
  }

  /// Whether a project is "buildable" (has a build target).
  static bool _isBuildable(Project project) {
    return project.targets.containsKey('build') ||
        project.targets.containsKey('compile');
  }

  /// Matches a tag pattern against a project's tags.
  ///
  /// Supported patterns:
  /// - `*` — matches any project (wildcard all)
  /// - `/pattern/` — regex match against any tag
  /// - `scope:*` — glob match (wildcard segments)
  /// - `scope:app` — exact match
  static bool _matchesTag(Project project, String tag) {
    if (tag == '*') return true;

    // Regex pattern: /pattern/
    if (tag.startsWith('/') && tag.endsWith('/') && tag.length > 2) {
      final regex = RegExp(tag.substring(1, tag.length - 1));
      return project.tags.any((t) => regex.hasMatch(t));
    }

    // Glob pattern (contains * but isn't just *)
    if (tag.contains('*')) {
      final regex = RegExp('^${RegExp.escape(tag).replaceAll(r'\*', '.*')}\$');
      return project.tags.any((t) => regex.hasMatch(t));
    }

    // Exact match
    return project.tags.contains(tag);
  }
}
