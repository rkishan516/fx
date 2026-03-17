import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/target.dart';
import '../models/workspace_config.dart';
import '../utils/fx_exception.dart';
import 'project_discovery.dart';
import 'workspace.dart';

/// Loads a workspace by finding the root and parsing configuration.
class WorkspaceLoader {
  /// Load workspace by finding the root starting from [startPath].
  ///
  /// Throws [WorkspaceNotFoundException] if no workspace is found.
  static Future<Workspace> load(String startPath) async {
    final rootPath = _findRoot(startPath);
    if (rootPath == null) {
      throw WorkspaceNotFoundException(startPath);
    }

    final config = _loadConfig(rootPath);
    final projects = await ProjectDiscovery.discover(rootPath, config);

    return Workspace(rootPath: rootPath, config: config, projects: projects);
  }

  /// Find workspace root from [startDir] by walking up.
  ///
  /// Priority: fx.yaml > pubspec.yaml with fx: > pubspec.yaml with workspace:
  static String? _findRoot(String startDir) {
    var dir = Directory(startDir);
    while (true) {
      // Prefer fx.yaml
      final fxYaml = File(p.join(dir.path, 'fx.yaml'));
      if (fxYaml.existsSync()) return dir.path;

      // Fall back to pubspec.yaml with fx: section or workspace: section
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains('\nfx:') || content.startsWith('fx:')) {
          return dir.path;
        }
        // Auto-detect: pubspec.yaml with workspace: section (Dart pub workspaces)
        if (content.contains('\nworkspace:') ||
            content.startsWith('workspace:')) {
          return dir.path;
        }
      }

      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  /// Load configuration from fx.yaml, pubspec.yaml fx: section,
  /// or auto-detect from pubspec.yaml workspace: section.
  static FxConfig _loadConfig(String rootPath) {
    // Prefer fx.yaml
    final fxYamlPath = p.join(rootPath, 'fx.yaml');
    final fxYaml = File(fxYamlPath);
    if (fxYaml.existsSync()) {
      final content = fxYaml.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;
      var config = FxConfig.fromYaml(yaml);

      // Handle config inheritance via extends
      if (config.extendsConfig != null) {
        config = _mergeWithBase(rootPath, config);
      }
      return config;
    }

    // Fall back to pubspec.yaml fx: section
    final pubspecPath = p.join(rootPath, 'pubspec.yaml');
    final pubspec = File(pubspecPath);
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;
      final fxSection = yaml['fx'];
      if (fxSection is YamlMap) {
        return FxConfig.fromYaml(fxSection);
      }

      // Auto-detect from workspace: section
      final workspace = yaml['workspace'];
      if (workspace is YamlList) {
        return _autoDetectConfig(workspace);
      }
    }

    return FxConfig.defaults();
  }

  /// Merges a config with its base config specified by `extends`.
  static FxConfig _mergeWithBase(String rootPath, FxConfig config) {
    final basePath = p.join(rootPath, config.extendsConfig!);
    final baseFile = File(basePath);
    if (!baseFile.existsSync()) return config;

    final baseContent = baseFile.readAsStringSync();
    final baseYaml = loadYaml(baseContent) as YamlMap;
    final baseConfig = FxConfig.fromYaml(baseYaml);

    // Child config overrides base config
    return FxConfig(
      packages: config.packages.isNotEmpty
          ? config.packages
          : baseConfig.packages,
      targets: {...baseConfig.targets, ...config.targets},
      targetDefaults: {...baseConfig.targetDefaults, ...config.targetDefaults},
      namedInputs: {...baseConfig.namedInputs, ...config.namedInputs},
      moduleBoundaries: config.moduleBoundaries.isNotEmpty
          ? config.moduleBoundaries
          : baseConfig.moduleBoundaries,
      cacheConfig: config.cacheConfig,
      generators: config.generators.isNotEmpty
          ? config.generators
          : baseConfig.generators,
      pluginConfigs: config.pluginConfigs.isNotEmpty
          ? config.pluginConfigs
          : baseConfig.pluginConfigs,
      scripts: {...baseConfig.scripts, ...config.scripts},
      defaultBase: config.defaultBase,
      generatorDefaults: {
        ...baseConfig.generatorDefaults,
        ...config.generatorDefaults,
      },
      configurations: {...baseConfig.configurations, ...config.configurations},
      conformanceRules: config.conformanceRules.isNotEmpty
          ? config.conformanceRules
          : baseConfig.conformanceRules,
      captureStderr: config.captureStderr,
    );
  }

  /// Builds an FxConfig from Dart pub workspace members.
  ///
  /// Infers default targets (test, analyze, format) and uses workspace
  /// members as package patterns.
  static FxConfig _autoDetectConfig(YamlList workspaceMembers) {
    final packages = workspaceMembers.map((e) => e.toString()).toList();

    return FxConfig(
      packages: packages,
      targets: {
        'test': Target(
          name: 'test',
          executor: 'dart test',
          inputs: ['lib/**', 'test/**'],
        ),
        'analyze': Target(
          name: 'analyze',
          executor: 'dart analyze',
          inputs: ['lib/**'],
        ),
        'format': Target(
          name: 'format',
          executor: 'dart format .',
          inputs: ['lib/**', 'test/**'],
        ),
      },
      cacheConfig: CacheConfig.defaults(),
      generators: [],
    );
  }
}
