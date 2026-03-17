import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;

/// A conformance rule violation.
class ConformanceViolation {
  final String projectName;
  final String ruleId;
  final String message;

  /// Whether this violation is just a warning (evaluated) vs error (enforced).
  final bool isWarning;

  const ConformanceViolation({
    required this.projectName,
    required this.ruleId,
    required this.message,
    this.isWarning = false,
  });

  @override
  String toString() => '$projectName: [$ruleId] $message';
}

/// A conformance rule definition from workspace config.
class ConformanceRule {
  final String id;
  final String type;
  final Map<String, dynamic> options;

  const ConformanceRule({
    required this.id,
    required this.type,
    this.options = const {},
  });

  factory ConformanceRule.fromYaml(Map<dynamic, dynamic> yaml) {
    return ConformanceRule(
      id: yaml['id']?.toString() ?? yaml['type']?.toString() ?? 'unknown',
      type: yaml['type']?.toString() ?? '',
      options: yaml['options'] is Map
          ? Map<String, dynamic>.from(yaml['options'] as Map)
          : const {},
    );
  }
}

/// Interface for pluggable conformance rule handlers.
///
/// Implement this to create custom conformance rules that can be registered
/// with [ConformanceRegistry].
abstract class ConformanceRuleHandler {
  /// The rule type identifier (e.g., 'require-target', 'max-dependencies').
  String get type;

  /// Evaluate this rule against the given projects.
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  });
}

/// Registry of conformance rule handlers.
///
/// Pre-populated with built-in handlers via [ConformanceRegistry.withBuiltIns].
/// Custom handlers can be added via [register].
class ConformanceRegistry {
  final Map<String, ConformanceRuleHandler> _handlers = {};

  ConformanceRegistry();

  /// Creates a registry with all built-in rule handlers.
  factory ConformanceRegistry.withBuiltIns() {
    return ConformanceRegistry()
      ..register(RequireTargetHandler())
      ..register(RequireInputsHandler())
      ..register(RequireTagsHandler())
      ..register(BanDependencyHandler())
      ..register(MaxDependenciesHandler())
      ..register(NamingConventionHandler())
      ..register(EnsureOwnersHandler());
  }

  /// Register a custom rule handler. Overwrites any existing handler for
  /// the same [ConformanceRuleHandler.type].
  void register(ConformanceRuleHandler handler) {
    _handlers[handler.type] = handler;
  }

  /// Returns the handler for [type], or null if not registered.
  ConformanceRuleHandler? get(String type) => _handlers[type];

  /// All registered handler types.
  List<String> get types => List.unmodifiable(_handlers.keys);
}

/// Enforces conformance rules across workspace projects.
///
/// Built-in rule types:
/// - `require-target`: Every project must define or inherit a specific target.
/// - `require-inputs`: Targets must have input patterns configured.
/// - `require-tags`: Every project must have at least one tag.
/// - `ban-dependency`: Projects must not depend on a specific package.
/// - `max-dependencies`: Projects must not exceed a dependency count.
/// - `naming-convention`: Project names must match a regex pattern.
/// - `ensure-owners`: Every project must have an owner in CODEOWNERS.
///
/// Supports rule status (enforced/evaluated/disabled) and project matchers
/// when using [ConformanceRuleConfig] from workspace config.
class ConformanceEnforcer {
  static List<ConformanceViolation> enforce({
    required List<Project> projects,
    required List<ConformanceRule> rules,
    required FxConfig config,
    ConformanceRegistry? registry,
  }) {
    if (rules.isEmpty) return const [];

    final reg = registry ?? ConformanceRegistry.withBuiltIns();
    final violations = <ConformanceViolation>[];

    for (final rule in rules) {
      final handler = reg.get(rule.type);
      if (handler == null) continue; // unknown rule type — skip
      violations.addAll(
        handler.evaluate(projects: projects, rule: rule, config: config),
      );
    }

    return violations;
  }

  /// Enhanced enforcement using [ConformanceRuleConfig] which supports
  /// rule status (enforced/evaluated/disabled) and project matchers.
  static List<ConformanceViolation> enforceWithConfig({
    required List<Project> projects,
    required List<ConformanceRuleConfig> rules,
    required FxConfig config,
    ConformanceRegistry? registry,
    String? workspaceRoot,
  }) {
    if (rules.isEmpty) return const [];

    final reg = registry ?? ConformanceRegistry.withBuiltIns();
    final violations = <ConformanceViolation>[];

    for (final ruleConfig in rules) {
      // Skip disabled rules
      if (ruleConfig.status == ConformanceRuleStatus.disabled) continue;

      final handler = reg.get(ruleConfig.type);
      if (handler == null) continue;

      // Filter projects based on project matchers
      final matchedProjects = ruleConfig.projects.isEmpty
          ? projects
          : projects.where((p) => ruleConfig.appliesTo(p.name)).toList();

      if (matchedProjects.isEmpty) continue;

      // Create legacy ConformanceRule for handler compatibility
      final legacyRule = ConformanceRule(
        id: ruleConfig.id,
        type: ruleConfig.type,
        options: {...ruleConfig.options, '_workspaceRoot': ?workspaceRoot},
      );

      final ruleViolations = handler.evaluate(
        projects: matchedProjects,
        rule: legacyRule,
        config: config,
      );

      // Mark as warning if rule is in "evaluated" status
      if (ruleConfig.status == ConformanceRuleStatus.evaluated) {
        violations.addAll(
          ruleViolations.map(
            (v) => ConformanceViolation(
              projectName: v.projectName,
              ruleId: v.ruleId,
              message: v.message,
              isWarning: true,
            ),
          ),
        );
      } else {
        violations.addAll(ruleViolations);
      }
    }

    return violations;
  }
}

// ---------------------------------------------------------------------------
// Built-in rule handlers
// ---------------------------------------------------------------------------

/// Requires every project to define or inherit a specific target.
class RequireTargetHandler extends ConformanceRuleHandler {
  @override
  String get type => 'require-target';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) {
    final targetName = rule.options['target'] as String?;
    if (targetName == null) return const [];

    final violations = <ConformanceViolation>[];
    for (final project in projects) {
      final hasProjectTarget = project.targets.containsKey(targetName);
      final hasWorkspaceTarget = config.targets.containsKey(targetName);
      if (!hasProjectTarget && !hasWorkspaceTarget) {
        violations.add(
          ConformanceViolation(
            projectName: project.name,
            ruleId: rule.id,
            message: 'Missing required target "$targetName"',
          ),
        );
      }
    }
    return violations;
  }
}

/// Requires targets to have input patterns configured.
class RequireInputsHandler extends ConformanceRuleHandler {
  @override
  String get type => 'require-inputs';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) {
    final targetName = rule.options['target'] as String?;
    if (targetName == null) return const [];

    final violations = <ConformanceViolation>[];
    for (final project in projects) {
      final resolved = config.resolveTarget(
        targetName,
        projectTarget: project.targets[targetName],
      );
      if (resolved == null) continue;
      if (resolved.inputs.isEmpty) {
        violations.add(
          ConformanceViolation(
            projectName: project.name,
            ruleId: rule.id,
            message: 'Target "$targetName" must define input patterns',
          ),
        );
      }
    }
    return violations;
  }
}

/// Requires every project to have at least one tag.
class RequireTagsHandler extends ConformanceRuleHandler {
  @override
  String get type => 'require-tags';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) {
    final violations = <ConformanceViolation>[];
    for (final project in projects) {
      if (project.tags.isEmpty) {
        violations.add(
          ConformanceViolation(
            projectName: project.name,
            ruleId: rule.id,
            message: 'Project must have at least one tag',
          ),
        );
      }
    }
    return violations;
  }
}

/// Bans a specific dependency across all projects.
class BanDependencyHandler extends ConformanceRuleHandler {
  @override
  String get type => 'ban-dependency';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) {
    final banned = rule.options['package'] as String?;
    if (banned == null) return const [];

    final violations = <ConformanceViolation>[];
    for (final project in projects) {
      if (project.dependencies.contains(banned)) {
        violations.add(
          ConformanceViolation(
            projectName: project.name,
            ruleId: rule.id,
            message: 'Dependency on "$banned" is not allowed',
          ),
        );
      }
    }
    return violations;
  }
}

/// Enforces a maximum number of dependencies per project.
class MaxDependenciesHandler extends ConformanceRuleHandler {
  @override
  String get type => 'max-dependencies';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) {
    final max = rule.options['max'];
    if (max is! int) return const [];

    final violations = <ConformanceViolation>[];
    for (final project in projects) {
      if (project.dependencies.length > max) {
        violations.add(
          ConformanceViolation(
            projectName: project.name,
            ruleId: rule.id,
            message:
                'Project has ${project.dependencies.length} dependencies, '
                'exceeding maximum of $max',
          ),
        );
      }
    }
    return violations;
  }
}

/// Enforces a naming convention for project names via regex.
class NamingConventionHandler extends ConformanceRuleHandler {
  @override
  String get type => 'naming-convention';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) {
    final pattern = rule.options['pattern'] as String?;
    if (pattern == null) return const [];

    final regex = RegExp(pattern);
    final violations = <ConformanceViolation>[];
    for (final project in projects) {
      if (!regex.hasMatch(project.name)) {
        violations.add(
          ConformanceViolation(
            projectName: project.name,
            ruleId: rule.id,
            message:
                'Project name "${project.name}" does not match pattern "$pattern"',
          ),
        );
      }
    }
    return violations;
  }
}

/// Requires every project to have an owner defined in a CODEOWNERS file.
///
/// Options:
/// - `codeownersPath` (String): Path to CODEOWNERS file relative to workspace
///   root. Defaults to `CODEOWNERS`, also checks `.github/CODEOWNERS` and
///   `docs/CODEOWNERS`.
class EnsureOwnersHandler extends ConformanceRuleHandler {
  @override
  String get type => 'ensure-owners';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) {
    final workspaceRoot = rule.options['_workspaceRoot'] as String?;
    if (workspaceRoot == null) return const [];

    final codeownersContent = _readCodeowners(
      workspaceRoot,
      rule.options['codeownersPath'] as String?,
    );

    if (codeownersContent == null) {
      return projects
          .map(
            (project) => ConformanceViolation(
              projectName: project.name,
              ruleId: rule.id,
              message: 'No CODEOWNERS file found in workspace',
            ),
          )
          .toList();
    }

    final ownedPaths = _parseCodeowners(codeownersContent);
    final violations = <ConformanceViolation>[];

    for (final project in projects) {
      final relativePath = p.relative(project.path, from: workspaceRoot);
      if (!_hasOwner(relativePath, ownedPaths)) {
        violations.add(
          ConformanceViolation(
            projectName: project.name,
            ruleId: rule.id,
            message:
                'Project "${project.name}" at $relativePath has no owner in CODEOWNERS',
          ),
        );
      }
    }

    return violations;
  }

  String? _readCodeowners(String workspaceRoot, String? explicitPath) {
    final candidates = explicitPath != null
        ? [explicitPath]
        : ['CODEOWNERS', '.github/CODEOWNERS', 'docs/CODEOWNERS'];

    for (final candidate in candidates) {
      final file = File(p.join(workspaceRoot, candidate));
      if (file.existsSync()) return file.readAsStringSync();
    }
    return null;
  }

  /// Parse CODEOWNERS into a list of path patterns.
  List<String> _parseCodeowners(String content) {
    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) => line.split(RegExp(r'\s+')).first)
        .toList();
  }

  /// Check if a project path is covered by any CODEOWNERS pattern.
  bool _hasOwner(String projectPath, List<String> ownedPaths) {
    final normalized = projectPath.replaceAll('\\', '/');
    for (final pattern in ownedPaths) {
      if (pattern == '*') return true;
      final cleanPattern = pattern.startsWith('/')
          ? pattern.substring(1)
          : pattern;
      if (normalized.startsWith(cleanPattern)) return true;
      if (cleanPattern.contains('*')) {
        final regex = RegExp(
          '^${RegExp.escape(cleanPattern).replaceAll(r'\*', '.*')}',
        );
        if (regex.hasMatch(normalized)) return true;
      }
    }
    return false;
  }
}
