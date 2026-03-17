import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fx_loader_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('WorkspaceLoader', () {
    test(
      'loads workspace from directory with pubspec.yaml fx: section',
      () async {
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
environment:
  sdk: ^3.11.1
fx:
  packages:
    - packages/*
''');
        Directory(p.join(tempDir.path, 'packages')).createSync();

        final workspace = await WorkspaceLoader.load(tempDir.path);
        expect(workspace.rootPath, tempDir.path);
        expect(workspace.config.packages, ['packages/*']);
      },
    );

    test('loads workspace from fx.yaml', () async {
      File(p.join(tempDir.path, 'fx.yaml')).writeAsStringSync('''
packages:
  - packages/*
  - apps/*
''');

      final workspace = await WorkspaceLoader.load(tempDir.path);
      expect(workspace.rootPath, tempDir.path);
      expect(workspace.config.packages, containsAll(['packages/*', 'apps/*']));
    });

    test('finds workspace root from subdirectory', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
environment:
  sdk: ^3.11.1
fx:
  packages:
    - packages/*
''');
      final subDir = Directory(p.join(tempDir.path, 'packages', 'my_pkg'))
        ..createSync(recursive: true);

      final workspace = await WorkspaceLoader.load(subDir.path);
      expect(workspace.rootPath, tempDir.path);
    });

    test('throws WorkspaceNotFoundException when no workspace found', () async {
      final isolated = Directory(p.join(tempDir.path, 'isolated'))
        ..createSync();
      expect(
        () => WorkspaceLoader.load(isolated.path),
        throwsA(isA<WorkspaceNotFoundException>()),
      );
    });

    test('prefers fx.yaml over pubspec.yaml fx: section', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: root
fx:
  packages:
    - from_pubspec/*
''');
      File(p.join(tempDir.path, 'fx.yaml')).writeAsStringSync('''
packages:
  - from_fxyaml/*
''');

      final workspace = await WorkspaceLoader.load(tempDir.path);
      expect(workspace.config.packages, ['from_fxyaml/*']);
    });

    test('discovers projects within workspace', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
environment:
  sdk: ^3.11.1
workspace:
  - packages/pkg_a
  - packages/pkg_b
fx:
  packages:
    - packages/*
''');
      for (final name in ['pkg_a', 'pkg_b']) {
        final dir = Directory(p.join(tempDir.path, 'packages', name))
          ..createSync(recursive: true);
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: $name
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');
      }

      final workspace = await WorkspaceLoader.load(tempDir.path);
      expect(workspace.projects, hasLength(2));
      final names = workspace.projects.map((p) => p.name).toSet();
      expect(names, containsAll(['pkg_a', 'pkg_b']));
    });

    test('loads targets from config', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: ws
fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
    build:
      executor: dart compile
''');
      Directory(p.join(tempDir.path, 'packages')).createSync();

      final workspace = await WorkspaceLoader.load(tempDir.path);
      expect(workspace.config.targets['test']?.executor, equals('dart test'));
      expect(
        workspace.config.targets['build']?.executor,
        equals('dart compile'),
      );
    });

    test('loads cache config', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: ws
fx:
  packages:
    - packages/*
  cache:
    enabled: true
    directory: .build_cache
''');
      Directory(p.join(tempDir.path, 'packages')).createSync();

      final workspace = await WorkspaceLoader.load(tempDir.path);
      expect(workspace.config.cacheConfig.enabled, isTrue);
      expect(workspace.config.cacheConfig.directory, equals('.build_cache'));
    });

    test('extends config merges base and child configs', () async {
      // Create base config
      File(p.join(tempDir.path, 'base.fx.yaml')).writeAsStringSync('''
packages:
  - packages/*
targets:
  test:
    executor: dart test
  analyze:
    executor: dart analyze
scripts:
  bootstrap: dart pub get
''');
      // Create fx.yaml that extends base
      File(p.join(tempDir.path, 'fx.yaml')).writeAsStringSync('''
extends: base.fx.yaml
targets:
  build:
    executor: dart compile
scripts:
  lint: dart analyze --fatal-infos
''');
      Directory(p.join(tempDir.path, 'packages')).createSync();

      final workspace = await WorkspaceLoader.load(tempDir.path);

      // Should have targets from both base and child
      expect(workspace.config.targets.containsKey('test'), isTrue);
      expect(workspace.config.targets.containsKey('analyze'), isTrue);
      expect(workspace.config.targets.containsKey('build'), isTrue);

      // Scripts should be merged
      expect(workspace.config.scripts['bootstrap'], 'dart pub get');
      expect(workspace.config.scripts['lint'], 'dart analyze --fatal-infos');
    });

    test('extends config child overrides base targets', () async {
      File(p.join(tempDir.path, 'base.fx.yaml')).writeAsStringSync('''
packages:
  - packages/*
targets:
  test:
    executor: dart test
''');
      File(p.join(tempDir.path, 'fx.yaml')).writeAsStringSync('''
extends: base.fx.yaml
targets:
  test:
    executor: flutter test
''');
      Directory(p.join(tempDir.path, 'packages')).createSync();

      final workspace = await WorkspaceLoader.load(tempDir.path);
      expect(workspace.config.targets['test']?.executor, 'flutter test');
    });
  });

  group('PluginLoader', () {
    PluginHook makeHook(String name, {String glob = '**/*.dart'}) =>
        _FakeHook(name: name, fileGlob: glob);

    test('fromWorkspace resolves hooks listed in pluginConfigs', () {
      final hook = makeHook('my_plugin');
      final config = FxConfig(
        packages: const ['packages/*'],
        targets: const {},
        cacheConfig: const CacheConfig(enabled: false, directory: '.fx_cache'),
        generators: const [],
        pluginConfigs: [const PluginConfig(plugin: 'my_plugin')],
      );
      final workspace = Workspace(
        rootPath: tempDir.path,
        config: config,
        projects: const [],
      );

      final hooks = PluginLoader.fromWorkspace(
        workspace,
        registry: {'my_plugin': (_) => hook},
      );

      expect(hooks, hasLength(1));
      expect(hooks.first.name, 'my_plugin');
    });

    test('fromWorkspace returns empty list when no plugins configured', () {
      final config = FxConfig(
        packages: const ['packages/*'],
        targets: const {},
        cacheConfig: const CacheConfig(enabled: false, directory: '.fx_cache'),
        generators: const [],
      );
      final workspace = Workspace(
        rootPath: tempDir.path,
        config: config,
        projects: const [],
      );

      final hooks = PluginLoader.fromWorkspace(workspace, registry: {});
      expect(hooks, isEmpty);
    });

    test(
      'fromWorkspace logs warning for unknown plugin but does not crash',
      () {
        final config = FxConfig(
          packages: const ['packages/*'],
          targets: const {},
          cacheConfig: const CacheConfig(
            enabled: false,
            directory: '.fx_cache',
          ),
          generators: const [],
          pluginConfigs: [const PluginConfig(plugin: 'unknown_plugin')],
        );
        final workspace = Workspace(
          rootPath: tempDir.path,
          config: config,
          projects: const [],
        );

        // Should not throw
        final hooks = PluginLoader.fromWorkspace(workspace, registry: {});
        expect(hooks, isEmpty);
      },
    );

    test('fromWorkspace sorts hooks by priority (higher first)', () {
      final hookA = makeHook('plugin_a');
      final hookB = makeHook('plugin_b');
      final config = FxConfig(
        packages: const ['packages/*'],
        targets: const {},
        cacheConfig: const CacheConfig(enabled: false, directory: '.fx_cache'),
        generators: const [],
        pluginConfigs: [
          const PluginConfig(plugin: 'plugin_a', priority: 5),
          const PluginConfig(plugin: 'plugin_b', priority: 10),
        ],
      );
      final workspace = Workspace(
        rootPath: tempDir.path,
        config: config,
        projects: const [],
      );

      final hooks = PluginLoader.fromWorkspace(
        workspace,
        registry: {'plugin_a': (_) => hookA, 'plugin_b': (_) => hookB},
      );

      expect(hooks.map((h) => h.name).toList(), ['plugin_b', 'plugin_a']);
    });

    test('plugin options are passed to factory', () {
      final receivedOptions = <Map<String, dynamic>>[];
      final config = FxConfig(
        packages: const ['packages/*'],
        targets: const {},
        cacheConfig: const CacheConfig(enabled: false, directory: '.fx_cache'),
        generators: const [],
        pluginConfigs: [
          PluginConfig(plugin: 'my_plugin', options: const {'foo': 'bar'}),
        ],
      );
      final workspace = Workspace(
        rootPath: tempDir.path,
        config: config,
        projects: const [],
      );

      PluginLoader.fromWorkspace(
        workspace,
        registry: {
          'my_plugin': (opts) {
            receivedOptions.add(opts);
            return makeHook('my_plugin');
          },
        },
      );

      expect(receivedOptions, hasLength(1));
      expect(receivedOptions.first['foo'], 'bar');
    });
  });
}

class _FakeHook implements PluginHook {
  @override
  final String name;
  @override
  final String fileGlob;

  _FakeHook({required this.name, required this.fileGlob});

  @override
  Future<List<Project>> inferProjects(
    String workspaceRoot,
    List<String> matchedFiles,
  ) async => [];

  @override
  Future<Map<String, List<String>>> inferDependencies(
    List<Project> projects,
  ) async => {};

  @override
  Future<InferredCacheConfig?> inferCacheConfig(
    Project project,
    Target target,
  ) async => null;

  @override
  Future<bool> preTasksExecution(TaskRunMetadata metadata) async => true;
  @override
  Future<void> postTasksExecution(
    TaskRunMetadata metadata,
    List<Map<String, dynamic>> results,
  ) async {}
  @override
  Future<Map<String, dynamic>> createMetadata(TaskRunMetadata metadata) async =>
      {};
}
