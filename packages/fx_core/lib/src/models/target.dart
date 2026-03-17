/// A dependency entry in a target's `dependsOn` list.
///
/// Can be a simple target name string or a structured object with
/// target name, project selector, and parameter forwarding.
class DependsOnEntry {
  /// Target name to depend on. May use `^` prefix for transitive deps
  /// or wildcard patterns like `build-*`.
  final String target;

  /// Optional project selector: `"dependencies"` means all dependency projects.
  final String? projects;

  /// When true, CLI arguments are forwarded to this dependency target.
  final bool params;

  const DependsOnEntry({
    required this.target,
    this.projects,
    this.params = false,
  });

  factory DependsOnEntry.fromYaml(dynamic yaml) {
    if (yaml is String) {
      return DependsOnEntry(target: yaml);
    }
    if (yaml is Map) {
      return DependsOnEntry(
        target: yaml['target']?.toString() ?? '',
        projects: yaml['projects'] as String?,
        params: yaml['params'] == 'forward' || yaml['params'] == true,
      );
    }
    return DependsOnEntry(target: yaml.toString());
  }

  Map<String, dynamic> toJson() => {
    'target': target,
    if (projects != null) 'projects': projects,
    if (params) 'params': 'forward',
  };

  @override
  String toString() => params ? '$target (forward params)' : target;
}

/// A named task configuration within a project.
class Target {
  final String name;
  final String executor;
  final List<String> inputs;
  final List<String> outputs;

  /// Dependencies as structured entries supporting parameter forwarding
  /// and project selectors.
  final List<DependsOnEntry> dependsOnEntries;

  /// Simple string list of dependency target names (convenience accessor).
  List<String> get dependsOn => dependsOnEntries.map((e) => e.target).toList();

  /// Whether this target's results should be cached. Defaults to true.
  /// When false, cache lookup/store is skipped even if caching is globally enabled.
  final bool cache;

  /// Whether this is a long-running continuous task (e.g., a dev server).
  /// When true, the task is started without awaiting its completion, allowing
  /// dependent tasks to proceed. The process is cleaned up when the run completes.
  final bool continuous;

  /// Whether this target can run concurrently with other tasks.
  /// When false, the task runner will not execute this target in parallel with
  /// other tasks — it runs alone. Defaults to true.
  final bool parallelism;

  /// Arbitrary options passed to the executor (e.g., as env vars or interpolated).
  final Map<String, dynamic> options;

  /// Named configuration presets that override [options] when selected.
  /// Keys are config names (e.g., "production", "development"), values are
  /// option maps merged on top of [options].
  final Map<String, Map<String, dynamic>> configurations;

  /// Default configuration name to use when no `--configuration` flag is passed.
  final String? defaultConfiguration;

  const Target({
    required this.name,
    required this.executor,
    this.inputs = const [],
    this.outputs = const [],
    this.dependsOnEntries = const [],
    this.cache = true,
    this.continuous = false,
    this.parallelism = true,
    this.options = const {},
    this.configurations = const {},
    this.defaultConfiguration,
  });

  factory Target.fromYaml(String name, Map<dynamic, dynamic> yaml) {
    final optionsRaw = yaml['options'];
    final options = <String, dynamic>{};
    if (optionsRaw is Map) {
      for (final entry in optionsRaw.entries) {
        options[entry.key.toString()] = entry.value;
      }
    }

    // Parse named configurations
    final configsRaw = yaml['configurations'] as Map?;
    final configurations = <String, Map<String, dynamic>>{};
    if (configsRaw != null) {
      for (final entry in configsRaw.entries) {
        final configName = entry.key.toString();
        if (entry.value is Map) {
          configurations[configName] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
    }

    return Target(
      name: name,
      executor: yaml['executor'] as String? ?? yaml['command'] as String? ?? '',
      inputs: _toStringList(yaml['inputs']),
      outputs: _toStringList(yaml['outputs']),
      dependsOnEntries: _toDependsOnList(yaml['dependsOn']),
      cache: yaml['cache'] as bool? ?? true,
      continuous: yaml['continuous'] as bool? ?? false,
      parallelism: yaml['parallelism'] as bool? ?? true,
      options: options,
      configurations: configurations,
      defaultConfiguration: yaml['defaultConfiguration'] as String?,
    );
  }

  factory Target.fromJson(Map<String, dynamic> json) {
    return Target(
      name: json['name'] as String,
      executor: json['executor'] as String,
      inputs: List<String>.from(json['inputs'] as List? ?? []),
      outputs: List<String>.from(json['outputs'] as List? ?? []),
      dependsOnEntries:
          (json['dependsOn'] as List?)?.map(DependsOnEntry.fromYaml).toList() ??
          const [],
      cache: json['cache'] as bool? ?? true,
      continuous: json['continuous'] as bool? ?? false,
      parallelism: json['parallelism'] as bool? ?? true,
      options: Map<String, dynamic>.from(json['options'] as Map? ?? {}),
      configurations:
          (json['configurations'] as Map?)?.map(
            (k, v) =>
                MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
          ) ??
          const {},
      defaultConfiguration: json['defaultConfiguration'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'executor': executor,
    'inputs': inputs,
    'outputs': outputs,
    'dependsOn': dependsOnEntries.map((e) => e.toJson()).toList(),
    'cache': cache,
    if (continuous) 'continuous': continuous,
    if (!parallelism) 'parallelism': parallelism,
    if (options.isNotEmpty) 'options': options,
    if (configurations.isNotEmpty) 'configurations': configurations,
    if (defaultConfiguration != null)
      'defaultConfiguration': defaultConfiguration,
  };

  /// Resolves options for a named configuration.
  ///
  /// Merges base [options] with the selected configuration's overrides.
  /// If [configName] is null, uses [defaultConfiguration].
  /// Returns base [options] if no configuration matches.
  Map<String, dynamic> resolveOptions({String? configName}) {
    final effectiveConfig = configName ?? defaultConfiguration;
    if (effectiveConfig == null) return options;
    final overrides = configurations[effectiveConfig];
    if (overrides == null) return options;
    return {...options, ...overrides};
  }

  Target copyWith({
    String? name,
    String? executor,
    List<String>? inputs,
    List<String>? outputs,
    List<DependsOnEntry>? dependsOnEntries,
    bool? cache,
    bool? continuous,
    bool? parallelism,
    Map<String, dynamic>? options,
    Map<String, Map<String, dynamic>>? configurations,
    String? defaultConfiguration,
  }) {
    return Target(
      name: name ?? this.name,
      executor: executor ?? this.executor,
      inputs: inputs ?? this.inputs,
      outputs: outputs ?? this.outputs,
      dependsOnEntries: dependsOnEntries ?? this.dependsOnEntries,
      cache: cache ?? this.cache,
      continuous: continuous ?? this.continuous,
      parallelism: parallelism ?? this.parallelism,
      options: options ?? this.options,
      configurations: configurations ?? this.configurations,
      defaultConfiguration: defaultConfiguration ?? this.defaultConfiguration,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }

  static List<DependsOnEntry> _toDependsOnList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map(DependsOnEntry.fromYaml).toList();
    return [DependsOnEntry.fromYaml(value)];
  }

  @override
  String toString() => 'Target($name, executor: $executor)';
}
