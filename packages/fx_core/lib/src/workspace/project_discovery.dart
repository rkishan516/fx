import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/project.dart';
import '../models/target.dart';
import '../models/workspace_config.dart';
import '../plugin/plugin_hook.dart';
import '../utils/file_utils.dart';
import '../utils/fx_exception.dart';
import '../utils/ignore_parser.dart';
import '../utils/logger.dart';
import '../utils/pubspec_parser.dart';

/// Discovers projects within a workspace based on configured glob patterns.
class ProjectDiscovery {
  /// Discover all projects in [rootPath] matching the [config] glob patterns.
  ///
  /// Throws [FxException] if duplicate package names are found.
  static Future<List<Project>> discover(
    String rootPath,
    FxConfig config,
  ) async {
    final ignoreParser = IgnoreParser.loadFromWorkspace(rootPath);
    var pubspecPaths = FileUtils.findPubspecs(rootPath, config.packages);

    // Filter out ignored paths
    if (ignoreParser != null) {
      pubspecPaths = pubspecPaths.where((pubspecPath) {
        final relative = p.relative(p.dirname(pubspecPath), from: rootPath);
        return !ignoreParser.shouldIgnore(relative);
      }).toList();
    }

    final projects = <Project>[];
    final seenNames = <String, String>{};

    for (final pubspecPath in pubspecPaths) {
      final content = File(pubspecPath).readAsStringSync();
      final pubspec = PubspecParser.parse(content, path: pubspecPath);

      final name = pubspec.name;
      if (name.isEmpty) continue;

      // Check for duplicate names
      if (seenNames.containsKey(name)) {
        throw FxException(
          'Duplicate project name "$name" found at:\n'
          '  - ${seenNames[name]}\n'
          '  - $pubspecPath',
          hint: 'Each project in the workspace must have a unique name.',
        );
      }
      seenNames[name] = pubspecPath;

      final projectDir = p.dirname(pubspecPath);
      final type = _detectType(projectDir, pubspec);
      final dependencies = _resolvePathDependencies(
        projectDir,
        rootPath,
        pubspec.pathDependencies,
        pubspecPaths,
      );

      final projectFx = _parseProjectFx(pubspec);

      projects.add(
        Project(
          name: name,
          path: projectDir,
          type: type,
          dependencies: dependencies,
          targets: _buildTargets(
            config,
            pubspec,
            projectFx,
            projectPath: projectDir,
          ),
          tags: projectFx.tags,
          hasBuildRunner: pubspec.hasBuildRunner,
        ),
      );
    }

    return projects;
  }

  /// Discover projects with additional inference from [hooks].
  ///
  /// Runs [discover] first to get pubspec.yaml-discovered projects, then
  /// calls each hook's [PluginHook.inferProjects] with files matching the
  /// hook's glob pattern. Plugin-inferred projects whose names conflict with
  /// pubspec-discovered projects are skipped with a debug warning.
  static Future<List<Project>> discoverWithPlugins(
    String rootPath,
    FxConfig config, {
    List<PluginHook> hooks = const [],
  }) async {
    final projects = await discover(rootPath, config);

    if (hooks.isEmpty) return projects;

    final knownNames = {for (final p in projects) p.name};
    final pluginProjects = <Project>[];

    for (final hook in hooks) {
      // Find files matching the hook's glob within the workspace
      final matchedFiles = FileUtils.findFiles(rootPath, [hook.fileGlob]);

      final inferred = await hook.inferProjects(rootPath, matchedFiles);
      for (final project in inferred) {
        if (knownNames.contains(project.name)) {
          Logger.verbose(
            'PluginHook "${hook.name}": skipping project "${project.name}" '
            '— already discovered from pubspec.yaml',
          );
          continue;
        }
        knownNames.add(project.name);
        pluginProjects.add(project);
      }
    }

    return [...projects, ...pluginProjects];
  }

  /// Determine the project type from its directory and pubspec data.
  static ProjectType _detectType(String dir, PubspecData pubspec) {
    if (pubspec.hasFlutterDependency) {
      // Flutter app has lib/main.dart
      final mainDart = File(p.join(dir, 'lib', 'main.dart'));
      return mainDart.existsSync()
          ? ProjectType.flutterApp
          : ProjectType.flutterPackage;
    }

    // Dart CLI has a bin/ directory
    final binDir = Directory(p.join(dir, 'bin'));
    if (binDir.existsSync()) return ProjectType.dartCli;

    return ProjectType.dartPackage;
  }

  /// Resolve path dependencies to project names within the workspace.
  static List<String> _resolvePathDependencies(
    String projectDir,
    String rootPath,
    Map<String, String> pathDeps,
    List<String> allPubspecPaths,
  ) {
    final resolved = <String>[];

    for (final entry in pathDeps.entries) {
      final depName = entry.key;
      final relativePath = entry.value;
      final absPath = p.normalize(p.join(projectDir, relativePath));
      final depPubspec = p.join(absPath, 'pubspec.yaml');

      // Check if this path dep is within the workspace
      if (allPubspecPaths.contains(depPubspec)) {
        resolved.add(depName);
      }
    }

    return resolved;
  }

  /// Parse the per-project `fx:` section from pubspec.yaml.
  static _ProjectFx _parseProjectFx(PubspecData pubspec) {
    final fxSection = pubspec.rawYaml['fx'];
    if (fxSection is! Map) return const _ProjectFx();

    final tags = <String>[];
    final tagsRaw = fxSection['tags'];
    if (tagsRaw is List) {
      tags.addAll(tagsRaw.map((e) => e.toString()));
    }

    final targets = <String, Target>{};
    final targetsRaw = fxSection['targets'] as Map?;
    if (targetsRaw != null) {
      for (final entry in targetsRaw.entries) {
        final name = entry.key.toString();
        final val = entry.value;
        if (val is Map) {
          targets[name] = Target.fromYaml(name, val);
        }
      }
    }

    return _ProjectFx(tags: tags, targets: targets);
  }

  /// Build target map by merging targetDefaults < workspace targets < project targets.
  /// Auto-injects targets based on project file detection (plugin auto-inference).
  static Map<String, Target> _buildTargets(
    FxConfig config,
    PubspecData pubspec,
    _ProjectFx projectFx, {
    String? projectPath,
  }) {
    final merged = <String, Target>{};

    // Collect all known target names
    final allNames = <String>{
      ...config.targetDefaults.keys,
      ...config.targets.keys,
      ...projectFx.targets.keys,
    };

    // Auto-inject build target for build_runner packages
    if (pubspec.hasBuildRunner && !allNames.contains('build')) {
      merged['build'] = Target(
        name: 'build',
        executor: 'dart run build_runner build --delete-conflicting-outputs',
        inputs: ['lib/**', 'build.yaml'],
        outputs: ['.dart_tool/build/**'],
      );
    }

    // Auto-infer targets from project structure
    if (projectPath != null) {
      final inferred = _inferTargets(projectPath, pubspec);
      for (final entry in inferred.entries) {
        if (!allNames.contains(entry.key)) {
          merged[entry.key] = entry.value;
        }
      }
    }

    for (final name in allNames) {
      final resolved = config.resolveTarget(
        name,
        projectTarget: projectFx.targets[name],
      );
      if (resolved != null) merged[name] = resolved;
    }

    return merged;
  }

  /// Infers targets from project file structure.
  ///
  /// Detects:
  /// - `test/` directory → test target
  /// - `analysis_options.yaml` → analyze target
  /// - `lib/` directory → format target
  /// - `bin/` directory → compile target for CLI apps
  /// - `integration_test/` → integration_test target (Flutter)
  static Map<String, Target> _inferTargets(
    String projectPath,
    PubspecData pubspec,
  ) {
    final targets = <String, Target>{};

    // test/ → dart test or flutter test
    if (Directory(p.join(projectPath, 'test')).existsSync()) {
      final executor = pubspec.hasFlutterDependency
          ? 'flutter test'
          : 'dart test';
      targets['test'] = Target(
        name: 'test',
        executor: executor,
        inputs: ['lib/**', 'test/**'],
      );
    }

    // analysis_options.yaml → dart analyze
    if (File(p.join(projectPath, 'analysis_options.yaml')).existsSync()) {
      targets['analyze'] = const Target(
        name: 'analyze',
        executor: 'dart analyze',
        inputs: ['lib/**', 'analysis_options.yaml'],
      );
    }

    // lib/ → dart format
    if (Directory(p.join(projectPath, 'lib')).existsSync()) {
      targets['format'] = const Target(
        name: 'format',
        executor: 'dart format .',
        inputs: ['lib/**'],
      );
    }

    // bin/ → compile exe for CLI apps
    if (Directory(p.join(projectPath, 'bin')).existsSync()) {
      final binFiles = Directory(
        p.join(projectPath, 'bin'),
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
      if (binFiles.isNotEmpty) {
        final mainFile = binFiles.first;
        final relPath = p.relative(mainFile.path, from: projectPath);
        targets['compile'] = Target(
          name: 'compile',
          executor: 'dart compile exe $relPath',
          inputs: ['lib/**', 'bin/**'],
          outputs: ['bin/*.exe'],
        );
      }
    }

    // integration_test/ → flutter test integration
    if (Directory(p.join(projectPath, 'integration_test')).existsSync()) {
      targets['integration_test'] = const Target(
        name: 'integration_test',
        executor: 'flutter test integration_test',
        inputs: ['lib/**', 'integration_test/**'],
      );
    }

    return targets;
  }
}

class _ProjectFx {
  final List<String> tags;
  final Map<String, Target> targets;

  const _ProjectFx({this.tags = const [], this.targets = const {}});
}
