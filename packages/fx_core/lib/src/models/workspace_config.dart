import 'config_types.dart';
import 'target.dart';

export 'config_types.dart';

/// Top-level fx configuration parsed from pubspec.yaml `fx:` section or fx.yaml.
class FxConfig {
  final List<String> packages;
  final Map<String, Target> targets;
  final Map<String, Target> targetDefaults;
  final Map<String, NamedInput> namedInputs;
  final List<ModuleBoundaryRule> moduleBoundaries;
  final CacheConfig cacheConfig;
  final List<String> generators;
  final List<PluginConfig> pluginConfigs;
  final Map<String, String> scripts;

  /// Default git base ref for affected analysis (e.g., 'main', 'develop').
  final String defaultBase;

  /// Path to a base config file to inherit from (e.g., 'base.fx.yaml').
  final String? extendsConfig;

  /// Default options for generators, keyed by generator name.
  final Map<String, Map<String, dynamic>> generatorDefaults;

  /// Named configurations (e.g., production, development) that override
  /// target settings.
  final Map<String, Map<String, dynamic>> configurations;

  /// Global default parallelism for task execution.
  final int? parallel;

  /// Global cache disable flag.
  final bool skipCache;

  /// Release configuration.
  final ReleaseConfig? releaseConfig;

  /// Sync configuration.
  final SyncConfig? syncConfig;

  /// TUI configuration.
  final TuiConfig? tuiConfig;

  /// Conformance rules enforced by `fx lint`.
  final List<ConformanceRuleConfig> conformanceRules;

  /// Whether to capture stderr separately in cache entries.
  final bool captureStderr;

  /// Whether to detect implicit dependencies via import analysis.
  ///
  /// When true, the project graph includes edges for `package:` imports
  /// that reference workspace projects not declared in `pubspec.yaml`.
  final bool dynamicDependencies;

  /// Controls how lock file changes affect project selection in `affected`.
  ///
  /// - `all` (default): lock file changes mark all projects as affected
  /// - `none`: lock file changes are ignored in affected analysis
  final String lockfileAffectsAll;

  const FxConfig({
    required this.packages,
    required this.targets,
    required this.cacheConfig,
    required this.generators,
    this.pluginConfigs = const [],
    this.targetDefaults = const {},
    this.namedInputs = const {},
    this.moduleBoundaries = const [],
    this.scripts = const {},
    this.defaultBase = 'main',
    this.extendsConfig,
    this.generatorDefaults = const {},
    this.configurations = const {},
    this.parallel,
    this.skipCache = false,
    this.releaseConfig,
    this.syncConfig,
    this.tuiConfig,
    this.conformanceRules = const [],
    this.captureStderr = false,
    this.dynamicDependencies = false,
    this.lockfileAffectsAll = 'all',
  });

  factory FxConfig.defaults() => const FxConfig(
    packages: ['packages/*'],
    targets: {},
    cacheConfig: CacheConfig(enabled: false, directory: '.fx_cache'),
    generators: [],
  );

  /// Resolves a target by merging project target, workspace target, and
  /// targetDefaults (in that priority order).
  Target? resolveTarget(String name, {Target? projectTarget}) {
    final wsTarget = targets[name];
    final defaultTarget = targetDefaults[name];

    if (projectTarget == null && wsTarget == null && defaultTarget == null) {
      return null;
    }

    // Merge: defaults < workspace < project
    var executor = defaultTarget?.executor ?? '';
    var inputs = defaultTarget?.inputs ?? const [];
    var outputs = defaultTarget?.outputs ?? const [];
    var dependsOnEntries =
        defaultTarget?.dependsOnEntries ?? const <DependsOnEntry>[];
    var cache = defaultTarget?.cache ?? true;
    var options = defaultTarget?.options ?? const <String, dynamic>{};

    if (wsTarget != null) {
      if (wsTarget.executor.isNotEmpty) executor = wsTarget.executor;
      if (wsTarget.inputs.isNotEmpty) inputs = wsTarget.inputs;
      if (wsTarget.outputs.isNotEmpty) outputs = wsTarget.outputs;
      if (wsTarget.dependsOnEntries.isNotEmpty) {
        dependsOnEntries = wsTarget.dependsOnEntries;
      }
      cache = wsTarget.cache;
      if (wsTarget.options.isNotEmpty) {
        options = {...options, ...wsTarget.options};
      }
    }

    if (projectTarget != null) {
      if (projectTarget.executor.isNotEmpty) executor = projectTarget.executor;
      if (projectTarget.inputs.isNotEmpty) inputs = projectTarget.inputs;
      if (projectTarget.outputs.isNotEmpty) outputs = projectTarget.outputs;
      if (projectTarget.dependsOnEntries.isNotEmpty) {
        dependsOnEntries = projectTarget.dependsOnEntries;
      }
      cache = projectTarget.cache;
      if (projectTarget.options.isNotEmpty) {
        options = {...options, ...projectTarget.options};
      }
    }

    return Target(
      name: name,
      executor: executor,
      inputs: inputs,
      outputs: outputs,
      dependsOnEntries: dependsOnEntries,
      cache: cache,
      options: options,
    );
  }

  /// Resolves named input patterns. If the input starts with `{`, it's a
  /// reference to a named input (e.g., `{default}`, `{production}`).
  /// Otherwise it's a literal glob pattern.
  List<String> resolveInputPatterns(
    List<String> inputs, [
    Set<String>? visited,
  ]) {
    visited ??= {};
    final resolved = <String>[];
    for (final input in inputs) {
      if (input.startsWith('{') && input.endsWith('}')) {
        final namedKey = input.substring(1, input.length - 1);
        if (visited.contains(namedKey)) continue; // break circular refs
        visited.add(namedKey);
        final named = namedInputs[namedKey];
        if (named != null) {
          resolved.addAll(resolveInputPatterns(named.patterns, visited));
        }
      } else {
        resolved.add(input);
      }
    }
    return resolved;
  }

  factory FxConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    final pkgsRaw = yaml['packages'];
    final packages = pkgsRaw is List
        ? pkgsRaw.map((e) => e.toString()).toList()
        : <String>['packages/*'];

    final targetsRaw = yaml['targets'] as Map?;
    final targets = <String, Target>{};
    if (targetsRaw != null) {
      for (final entry in targetsRaw.entries) {
        final name = entry.key.toString();
        final val = entry.value;
        if (val is Map) {
          targets[name] = Target.fromYaml(name, val);
        }
      }
    }

    // Parse targetDefaults
    final defaultsRaw = yaml['targetDefaults'] as Map?;
    final targetDefaults = <String, Target>{};
    if (defaultsRaw != null) {
      for (final entry in defaultsRaw.entries) {
        final name = entry.key.toString();
        final val = entry.value;
        if (val is Map) {
          targetDefaults[name] = Target.fromYaml(name, val);
        }
      }
    }

    // Parse namedInputs
    final namedRaw = yaml['namedInputs'] as Map?;
    final namedInputs = <String, NamedInput>{};
    if (namedRaw != null) {
      for (final entry in namedRaw.entries) {
        final name = entry.key.toString();
        namedInputs[name] = NamedInput.fromYaml(name, entry.value);
      }
    }

    // Parse moduleBoundaries
    final boundariesRaw = yaml['moduleBoundaries'] as List?;
    final moduleBoundaries = <ModuleBoundaryRule>[];
    if (boundariesRaw != null) {
      for (final item in boundariesRaw) {
        if (item is Map) {
          moduleBoundaries.add(ModuleBoundaryRule.fromYaml(item));
        }
      }
    }

    final cacheRaw = yaml['cache'] as Map?;
    final cacheConfig = cacheRaw != null
        ? CacheConfig.fromYaml(cacheRaw)
        : CacheConfig.defaults();

    final generatorsRaw = yaml['generators'];
    final generators = generatorsRaw is List
        ? generatorsRaw.map((e) => e.toString()).toList()
        : <String>[];

    // Parse plugins with include/exclude scoping
    final pluginsRaw = yaml['plugins'] as List?;
    final pluginConfigs = <PluginConfig>[];
    if (pluginsRaw != null) {
      for (final item in pluginsRaw) {
        pluginConfigs.add(PluginConfig.fromYaml(item));
      }
    }

    final scriptsRaw = yaml['scripts'] as Map?;
    final scripts = <String, String>{};
    if (scriptsRaw != null) {
      for (final entry in scriptsRaw.entries) {
        scripts[entry.key.toString()] = entry.value.toString();
      }
    }

    final defaultBase = yaml['defaultBase'] as String? ?? 'main';
    final extendsConfig = yaml['extends'] as String?;

    // Parse generator defaults
    final genDefaultsRaw = yaml['generatorDefaults'] as Map?;
    final generatorDefaults = <String, Map<String, dynamic>>{};
    if (genDefaultsRaw != null) {
      for (final entry in genDefaultsRaw.entries) {
        final name = entry.key.toString();
        if (entry.value is Map) {
          generatorDefaults[name] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
    }

    // Parse named configurations (e.g., production, development)
    final configurationsRaw = yaml['configurations'] as Map?;
    final configurations = <String, Map<String, dynamic>>{};
    if (configurationsRaw != null) {
      for (final entry in configurationsRaw.entries) {
        final name = entry.key.toString();
        if (entry.value is Map) {
          configurations[name] = Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }

    // Parse parallel, skipCache, release, sync
    final parallel = yaml['parallel'] as int?;
    final skipCache = yaml['skipCache'] as bool? ?? false;

    final releaseRaw = yaml['release'] as Map?;
    final releaseConfig = releaseRaw != null
        ? ReleaseConfig.fromYaml(releaseRaw)
        : null;

    final syncRaw = yaml['sync'] as Map?;
    final syncConfig = syncRaw != null ? SyncConfig.fromYaml(syncRaw) : null;

    final tuiRaw = yaml['tui'] as Map?;
    final tuiConfig = tuiRaw != null ? TuiConfig.fromYaml(tuiRaw) : null;

    // Parse conformance rules
    final conformanceRaw = yaml['conformanceRules'] as List?;
    final conformanceRules = <ConformanceRuleConfig>[];
    if (conformanceRaw != null) {
      for (final item in conformanceRaw) {
        if (item is Map) {
          conformanceRules.add(ConformanceRuleConfig.fromYaml(item));
        }
      }
    }

    final captureStderr = yaml['captureStderr'] as bool? ?? false;
    final dynamicDependencies = yaml['dynamicDependencies'] as bool? ?? false;
    final lockfileAffectsAll = yaml['lockfileAffectsAll'] as String? ?? 'all';

    return FxConfig(
      packages: packages,
      targets: targets,
      targetDefaults: targetDefaults,
      namedInputs: namedInputs,
      moduleBoundaries: moduleBoundaries,
      cacheConfig: cacheConfig,
      generators: generators,
      pluginConfigs: pluginConfigs,
      scripts: scripts,
      defaultBase: defaultBase,
      extendsConfig: extendsConfig,
      generatorDefaults: generatorDefaults,
      configurations: configurations,
      parallel: parallel,
      skipCache: skipCache,
      releaseConfig: releaseConfig,
      syncConfig: syncConfig,
      tuiConfig: tuiConfig,
      conformanceRules: conformanceRules,
      captureStderr: captureStderr,
      dynamicDependencies: dynamicDependencies,
      lockfileAffectsAll: lockfileAffectsAll,
    );
  }

  @override
  String toString() =>
      'FxConfig(packages: $packages, targets: ${targets.keys.toList()})';
}
