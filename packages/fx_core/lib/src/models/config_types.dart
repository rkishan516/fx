/// Cache configuration settings.
class CacheConfig {
  final bool enabled;
  final String directory;
  final String? remoteUrl;
  final int? maxSize; // in MB

  /// Remote backend type: 'http', 's3', 'gcs', 'azure', 'filesystem'.
  final String? remoteBackend;

  /// Backend-specific options (e.g., bucket, region, container, accountName).
  final Map<String, dynamic> remoteOptions;

  const CacheConfig({
    required this.enabled,
    required this.directory,
    this.remoteUrl,
    this.maxSize,
    this.remoteBackend,
    this.remoteOptions = const {},
  });

  factory CacheConfig.defaults() =>
      const CacheConfig(enabled: false, directory: '.fx_cache');

  factory CacheConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    final remoteRaw = yaml['remote'];
    String? remoteUrl;
    String? remoteBackend;
    Map<String, dynamic> remoteOptions = const {};

    if (remoteRaw is String) {
      // Simple form: remote: https://cache-server.com
      remoteUrl = remoteRaw;
      remoteBackend = 'http';
    } else if (remoteRaw is Map) {
      // Structured form:
      //   remote:
      //     backend: s3
      //     bucket: my-cache
      //     region: us-east-1
      remoteBackend = remoteRaw['backend'] as String?;
      remoteUrl = remoteRaw['url'] as String?;
      remoteOptions = Map<String, dynamic>.from(remoteRaw)
        ..remove('backend')
        ..remove('url');
    } else {
      // Legacy field
      remoteUrl = yaml['remoteUrl'] as String?;
      if (remoteUrl != null) remoteBackend = 'http';
    }

    return CacheConfig(
      enabled: yaml['enabled'] as bool? ?? false,
      directory: yaml['directory'] as String? ?? '.fx_cache',
      remoteUrl: remoteUrl,
      maxSize: yaml['maxSize'] as int?,
      remoteBackend: remoteBackend,
      remoteOptions: remoteOptions,
    );
  }

  @override
  String toString() => 'CacheConfig(enabled: $enabled, dir: $directory)';
}

/// A named set of input glob patterns for cache keying.
class NamedInput {
  final String name;
  final List<String> patterns;

  const NamedInput({required this.name, required this.patterns});

  factory NamedInput.fromYaml(String name, dynamic yaml) {
    if (yaml is List) {
      return NamedInput(
        name: name,
        patterns: yaml.map((e) => e.toString()).toList(),
      );
    }
    return NamedInput(name: name, patterns: []);
  }
}

/// A module boundary rule constraining which tags can depend on which.
class ModuleBoundaryRule {
  final String sourceTag;

  /// When set, the rule only applies to projects that have ALL of these tags.
  /// Takes precedence over [sourceTag] when non-empty.
  final List<String> allSourceTags;

  final List<String> allowedTags;
  final List<String> deniedTags;

  /// Glob patterns for external (pub) packages that are banned for matching
  /// projects (e.g., `["package:http", "package:dio"]`).
  final List<String> bannedExternalImports;

  /// Glob patterns for external (pub) packages that are the ONLY ones allowed.
  /// When non-empty, any external import not matching is a violation.
  final List<String> allowedExternalImports;

  /// When true, importing a transitive dependency (one not declared directly
  /// in pubspec.yaml) is a violation.
  final bool banTransitiveDependencies;

  /// When true, non-buildable libraries cannot be imported by buildable ones.
  final bool enforceBuildableLibDependency;

  /// When true, a project may import from its own package name (circular self).
  final bool allowCircularSelfDependency;

  const ModuleBoundaryRule({
    required this.sourceTag,
    this.allSourceTags = const [],
    this.allowedTags = const [],
    this.deniedTags = const [],
    this.bannedExternalImports = const [],
    this.allowedExternalImports = const [],
    this.banTransitiveDependencies = false,
    this.enforceBuildableLibDependency = false,
    this.allowCircularSelfDependency = false,
  });

  factory ModuleBoundaryRule.fromYaml(Map<dynamic, dynamic> yaml) {
    return ModuleBoundaryRule(
      sourceTag: yaml['sourceTag']?.toString() ?? '*',
      allSourceTags: _toStringList(yaml['allSourceTags']),
      allowedTags: _toStringList(yaml['onlyDependOnLibsWithTags']),
      deniedTags: _toStringList(yaml['notDependOnLibsWithTags']),
      bannedExternalImports: _toStringList(yaml['bannedExternalImports']),
      allowedExternalImports: _toStringList(yaml['allowedExternalImports']),
      banTransitiveDependencies:
          yaml['banTransitiveDependencies'] as bool? ?? false,
      enforceBuildableLibDependency:
          yaml['enforceBuildableLibDependency'] as bool? ?? false,
      allowCircularSelfDependency:
          yaml['allowCircularSelfDependency'] as bool? ?? false,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }
}

/// A release group that coordinates versioning for a set of projects.
class ReleaseGroup {
  final String name;
  final List<String> projects;
  final String? projectsRelationship;

  /// Custom version actions to run during release (e.g., update changelogs,
  /// run custom scripts per project).
  final List<VersionAction> versionActions;

  const ReleaseGroup({
    required this.name,
    this.projects = const [],
    this.projectsRelationship,
    this.versionActions = const [],
  });

  factory ReleaseGroup.fromYaml(String name, Map<dynamic, dynamic> yaml) {
    final actionsRaw = yaml['versionActions'] as List?;
    final versionActions = <VersionAction>[];
    if (actionsRaw != null) {
      for (final item in actionsRaw) {
        if (item is Map) {
          versionActions.add(VersionAction.fromYaml(item));
        }
      }
    }

    return ReleaseGroup(
      name: name,
      projects: yaml['projects'] is List
          ? (yaml['projects'] as List).map((e) => e.toString()).toList()
          : const [],
      projectsRelationship: yaml['projectsRelationship'] as String?,
      versionActions: versionActions,
    );
  }
}

/// A custom action to run during version bumps.
class VersionAction {
  /// Command to execute (supports {version}, {projectName}, {projectRoot} placeholders).
  final String command;

  /// When to run: 'pre' (before version bump) or 'post' (after version bump).
  final String phase;

  const VersionAction({required this.command, this.phase = 'post'});

  factory VersionAction.fromYaml(Map<dynamic, dynamic> yaml) {
    return VersionAction(
      command: yaml['command'] as String? ?? '',
      phase: yaml['phase'] as String? ?? 'post',
    );
  }
}

/// Release configuration settings.
class ReleaseConfig {
  final String projectsRelationship;
  final String releaseTagPattern;
  final Map<String, dynamic> changelog;
  final Map<String, dynamic> git;
  final Map<String, ReleaseGroup> groups;

  /// Controls how dependent project versions are updated when a dependency
  /// is bumped.
  ///
  /// - `always`: bump all dependent packages (patch) and update constraints
  /// - `auto`: update constraint only if the new version would break it
  /// - `never`: don't touch dependent packages
  final String updateDependents;

  /// When true, updating dependency version constraints preserves the
  /// existing range syntax (^, ~, >=<, etc.) instead of replacing with
  /// an exact version.
  final bool preserveMatchingDependencyRanges;

  /// Additional manifest files (relative to project root) to update
  /// version numbers in during release. Useful for projects with
  /// non-pubspec manifests (e.g., package.json for mixed Dart/JS projects).
  final List<String> manifestRootsToUpdate;

  /// Global version actions applied to all release groups.
  final List<VersionAction> versionActions;

  const ReleaseConfig({
    this.projectsRelationship = 'fixed',
    this.releaseTagPattern = 'v{version}',
    this.changelog = const {},
    this.git = const {},
    this.groups = const {},
    this.updateDependents = 'auto',
    this.preserveMatchingDependencyRanges = false,
    this.manifestRootsToUpdate = const [],
    this.versionActions = const [],
  });

  factory ReleaseConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    final groupsYaml = yaml['groups'];
    final groups = <String, ReleaseGroup>{};
    if (groupsYaml is Map) {
      for (final entry in groupsYaml.entries) {
        final name = entry.key.toString();
        if (entry.value is Map) {
          groups[name] = ReleaseGroup.fromYaml(name, entry.value as Map);
        }
      }
    }

    final manifestRoots = yaml['manifestRootsToUpdate'];
    final manifestRootsToUpdate = manifestRoots is List
        ? manifestRoots.map((e) => e.toString()).toList()
        : <String>[];

    final actionsRaw = yaml['versionActions'] as List?;
    final versionActions = <VersionAction>[];
    if (actionsRaw != null) {
      for (final item in actionsRaw) {
        if (item is Map) {
          versionActions.add(VersionAction.fromYaml(item));
        }
      }
    }

    return ReleaseConfig(
      projectsRelationship: yaml['projectsRelationship'] as String? ?? 'fixed',
      releaseTagPattern: yaml['releaseTagPattern'] as String? ?? 'v{version}',
      changelog: yaml['changelog'] is Map
          ? Map<String, dynamic>.from(yaml['changelog'] as Map)
          : const {},
      git: yaml['git'] is Map
          ? Map<String, dynamic>.from(yaml['git'] as Map)
          : const {},
      groups: groups,
      updateDependents: yaml['updateDependents'] as String? ?? 'auto',
      preserveMatchingDependencyRanges:
          yaml['preserveMatchingDependencyRanges'] as bool? ?? false,
      manifestRootsToUpdate: manifestRootsToUpdate,
      versionActions: versionActions,
    );
  }
}

/// Status of a conformance rule.
enum ConformanceRuleStatus {
  /// Violations cause failure.
  enforced,

  /// Violations are reported but don't cause failure.
  evaluated,

  /// Rule is not evaluated.
  disabled,
}

/// A project matcher for scoping conformance rules with an explanation.
class ConformanceProjectMatcher {
  /// Project name or glob pattern.
  final String matcher;

  /// Human-readable reason for why this project is included.
  final String? explanation;

  const ConformanceProjectMatcher({required this.matcher, this.explanation});

  factory ConformanceProjectMatcher.fromYaml(dynamic yaml) {
    if (yaml is String) {
      return ConformanceProjectMatcher(matcher: yaml);
    }
    if (yaml is Map) {
      return ConformanceProjectMatcher(
        matcher: yaml['matcher']?.toString() ?? '*',
        explanation: yaml['explanation'] as String?,
      );
    }
    return ConformanceProjectMatcher(matcher: yaml.toString());
  }

  /// Returns true if [projectName] matches this matcher.
  bool matches(String projectName) {
    if (matcher == '*') return true;
    if (!matcher.contains('*')) return projectName == matcher;
    final regex = RegExp(
      '^${RegExp.escape(matcher).replaceAll(r'\*', '.*')}\$',
    );
    return regex.hasMatch(projectName);
  }
}

/// A conformance rule definition for workspace-wide enforcement.
class ConformanceRuleConfig {
  final String id;
  final String type;
  final Map<String, dynamic> options;

  /// Rule status: enforced (fail on violation), evaluated (report only),
  /// or disabled (skip).
  final ConformanceRuleStatus status;

  /// Project matchers scoping which projects this rule applies to.
  /// Empty means all projects.
  final List<ConformanceProjectMatcher> projects;

  /// Human-readable explanation of why this rule exists.
  final String? explanation;

  const ConformanceRuleConfig({
    required this.id,
    required this.type,
    this.options = const {},
    this.status = ConformanceRuleStatus.enforced,
    this.projects = const [],
    this.explanation,
  });

  factory ConformanceRuleConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return ConformanceRuleConfig(
      id: yaml['id']?.toString() ?? yaml['type']?.toString() ?? 'unknown',
      type: yaml['type']?.toString() ?? '',
      options: yaml['options'] is Map
          ? Map<String, dynamic>.from(yaml['options'] as Map)
          : const {},
      status: _parseStatus(yaml['status']),
      projects: _parseProjects(yaml['projects']),
      explanation: yaml['explanation'] as String?,
    );
  }

  /// Whether this rule applies to a given project name.
  bool appliesTo(String projectName) {
    if (projects.isEmpty) return true;
    return projects.any((m) => m.matches(projectName));
  }

  static ConformanceRuleStatus _parseStatus(dynamic value) {
    if (value == null) return ConformanceRuleStatus.enforced;
    final str = value.toString();
    for (final s in ConformanceRuleStatus.values) {
      if (s.name == str) return s;
    }
    return ConformanceRuleStatus.enforced;
  }

  static List<ConformanceProjectMatcher> _parseProjects(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map(ConformanceProjectMatcher.fromYaml).toList();
    }
    return [ConformanceProjectMatcher.fromYaml(value)];
  }
}

/// TUI (Terminal UI) configuration settings.
class TuiConfig {
  final bool enabled;
  final dynamic autoExit; // bool or int (seconds)

  const TuiConfig({this.enabled = true, this.autoExit = false});

  factory TuiConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return TuiConfig(
      enabled: yaml['enabled'] as bool? ?? true,
      autoExit: yaml['autoExit'] ?? false,
    );
  }
}

/// Plugin configuration with optional include/exclude project scoping.
/// Declares what a plugin can do.
enum PluginCapability {
  /// Can infer additional projects from the workspace file tree.
  inference,

  /// Can contribute additional inter-project dependency edges.
  dependencies,

  /// Can provide custom task executors.
  executors,

  /// Can provide code generators.
  generators,

  /// Can provide workspace migration generators.
  migrations,
}

///
/// Supports two YAML formats:
/// - String: `"packages/generators/*"` (path only, applies to all projects)
/// - Map: `{plugin: "packages/generators/*", include: ["app_*"], exclude: ["*_test"],
///           options: {key: value}, capabilities: [inference], priority: 10}`
class PluginConfig {
  final String plugin;
  final List<String> include;
  final List<String> exclude;

  /// Typed plugin options passed to the plugin at load time.
  final Map<String, dynamic> options;

  /// Capability declarations for this plugin.
  final Set<PluginCapability> capabilities;

  /// Priority for ordering plugins when multiple apply. Higher runs first.
  final int priority;

  const PluginConfig({
    required this.plugin,
    this.include = const [],
    this.exclude = const [],
    this.options = const {},
    this.capabilities = const {},
    this.priority = 0,
  });

  factory PluginConfig.fromYaml(dynamic yaml) {
    if (yaml is String) {
      return PluginConfig(plugin: yaml);
    }
    if (yaml is Map) {
      return PluginConfig(
        plugin: yaml['plugin']?.toString() ?? '',
        include: _toList(yaml['include']),
        exclude: _toList(yaml['exclude']),
        options: yaml['options'] is Map
            ? Map<String, dynamic>.from(yaml['options'] as Map)
            : const {},
        capabilities: _parseCapabilities(yaml['capabilities']),
        priority: yaml['priority'] as int? ?? 0,
      );
    }
    return PluginConfig(plugin: yaml.toString());
  }

  static Set<PluginCapability> _parseCapabilities(dynamic value) {
    if (value == null) return const {};
    final list = value is List ? value : [value];
    final result = <PluginCapability>{};
    for (final item in list) {
      final name = item.toString();
      for (final cap in PluginCapability.values) {
        if (cap.name == name) {
          result.add(cap);
          break;
        }
      }
    }
    return result;
  }

  /// Returns true if [projectName] is allowed by include/exclude rules.
  /// Empty include = all included. Empty exclude = none excluded.
  bool appliesTo(String projectName) {
    if (include.isNotEmpty) {
      if (!_matchesAny(projectName, include)) return false;
    }
    if (exclude.isNotEmpty) {
      if (_matchesAny(projectName, exclude)) return false;
    }
    return true;
  }

  static bool _matchesAny(String name, List<String> patterns) {
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

  static List<String> _toList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }
}

/// Sync configuration settings.
class SyncConfig {
  final bool applyChanges;
  final List<String> disabledGenerators;

  const SyncConfig({
    this.applyChanges = false,
    this.disabledGenerators = const [],
  });

  factory SyncConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return SyncConfig(
      applyChanges: yaml['applyChanges'] as bool? ?? false,
      disabledGenerators: yaml['disabledGenerators'] is List
          ? (yaml['disabledGenerators'] as List)
                .map((e) => e.toString())
                .toList()
          : const [],
    );
  }
}
