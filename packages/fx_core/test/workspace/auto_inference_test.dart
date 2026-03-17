import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Plugin auto-inference', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_auto_infer_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('infers test target from test/ directory', () async {
      // Create a workspace with a package that has test/
      _createWorkspace(tempDir.path, 'test_ws');
      final pkgDir = _createPackage(tempDir.path, 'core');
      Directory(p.join(pkgDir, 'test')).createSync();

      final config = FxConfig.defaults();
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      final project = projects.firstWhere((p) => p.name == 'core');
      expect(project.targets, contains('test'));
      expect(project.targets['test']!.executor, equals('dart test'));
    });

    test('infers analyze target from analysis_options.yaml', () async {
      _createWorkspace(tempDir.path, 'test_ws');
      final pkgDir = _createPackage(tempDir.path, 'core');
      File(
        p.join(pkgDir, 'analysis_options.yaml'),
      ).writeAsStringSync('include: package:lints/recommended.yaml\n');

      final config = FxConfig.defaults();
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      final project = projects.firstWhere((p) => p.name == 'core');
      expect(project.targets, contains('analyze'));
    });

    test('infers compile target from bin/ directory', () async {
      _createWorkspace(tempDir.path, 'test_ws');
      final pkgDir = _createPackage(tempDir.path, 'cli_tool');
      final binDir = Directory(p.join(pkgDir, 'bin'));
      binDir.createSync();
      File(
        p.join(binDir.path, 'cli_tool.dart'),
      ).writeAsStringSync('void main() {}');

      final config = FxConfig.defaults();
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      final project = projects.firstWhere((p) => p.name == 'cli_tool');
      expect(project.targets, contains('compile'));
      expect(
        project.targets['compile']!.executor,
        contains('dart compile exe'),
      );
    });

    test('infers flutter test for flutter packages', () async {
      _createWorkspace(tempDir.path, 'test_ws');
      final pkgDir = p.join(tempDir.path, 'packages', 'flutter_pkg');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      Directory(p.join(pkgDir, 'test')).createSync();
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: flutter_pkg
version: 0.1.0
resolution: workspace
environment:
  sdk: ^3.11.1
dependencies:
  flutter:
    sdk: flutter
''');

      final config = FxConfig.defaults();
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      final project = projects.firstWhere((p) => p.name == 'flutter_pkg');
      expect(project.targets['test']!.executor, equals('flutter test'));
    });

    test('explicit targets override inferred targets', () async {
      _createWorkspace(tempDir.path, 'test_ws');
      final pkgDir = _createPackage(tempDir.path, 'custom');
      Directory(p.join(pkgDir, 'test')).createSync();

      // Add explicit test target in workspace config
      final config = FxConfig(
        packages: ['packages/*'],
        targets: {
          'test': const Target(
            name: 'test',
            executor: 'dart test --coverage',
            inputs: ['lib/**', 'test/**'],
          ),
        },
        cacheConfig: CacheConfig.defaults(),
        generators: [],
      );

      final projects = await ProjectDiscovery.discover(tempDir.path, config);
      final project = projects.firstWhere((p) => p.name == 'custom');
      expect(project.targets['test']!.executor, equals('dart test --coverage'));
    });
  });

  group('PluginHook inference', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_plugin_hook_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('PluginHook subclass can be instantiated', () {
      final hook = _TestHook();
      expect(hook.name, 'test-hook');
      expect(hook.fileGlob, '**/*.custom');
    });

    test(
      'discoverWithPlugins with no hooks discovers projects as before',
      () async {
        _createWorkspace(tempDir.path, 'ws');
        _createPackage(tempDir.path, 'alpha');

        final config = FxConfig.defaults();
        final projects = await ProjectDiscovery.discoverWithPlugins(
          tempDir.path,
          config,
          hooks: [],
        );
        expect(projects.any((p) => p.name == 'alpha'), isTrue);
      },
    );

    test(
      'discoverWithPlugins with a test hook discovers additional projects',
      () async {
        _createWorkspace(tempDir.path, 'ws');
        _createPackage(tempDir.path, 'base');

        final hook = _TestHook(
          extraProjects: [
            Project(
              name: 'plugin_inferred',
              path: p.join(tempDir.path, 'custom'),
              type: ProjectType.dartPackage,
              dependencies: [],
              targets: {},
            ),
          ],
        );

        final config = FxConfig.defaults();
        final projects = await ProjectDiscovery.discoverWithPlugins(
          tempDir.path,
          config,
          hooks: [hook],
        );
        expect(projects.any((p) => p.name == 'base'), isTrue);
        expect(projects.any((p) => p.name == 'plugin_inferred'), isTrue);
      },
    );

    test(
      'plugin-inferred project with same name as pubspec project is skipped',
      () async {
        _createWorkspace(tempDir.path, 'ws');
        _createPackage(tempDir.path, 'alpha');

        // Hook tries to infer a project also named 'alpha'
        final hook = _TestHook(
          extraProjects: [
            Project(
              name: 'alpha', // same name as pubspec-discovered
              path: '/different/path',
              type: ProjectType.dartPackage,
              dependencies: [],
              targets: {},
            ),
          ],
        );

        final config = FxConfig.defaults();
        final projects = await ProjectDiscovery.discoverWithPlugins(
          tempDir.path,
          config,
          hooks: [hook],
        );
        // Only one 'alpha', from pubspec
        final alphaProjects = projects.where((p) => p.name == 'alpha').toList();
        expect(alphaProjects, hasLength(1));
        expect(alphaProjects.first.path, isNot('/different/path'));
      },
    );

    test('plugin that returns empty list does not affect discovery', () async {
      _createWorkspace(tempDir.path, 'ws');
      _createPackage(tempDir.path, 'beta');

      final hook = _TestHook(extraProjects: []);
      final config = FxConfig.defaults();
      final projects = await ProjectDiscovery.discoverWithPlugins(
        tempDir.path,
        config,
        hooks: [hook],
      );
      expect(projects.any((p) => p.name == 'beta'), isTrue);
      expect(projects, hasLength(1));
    });
  });
}

/// A test PluginHook that returns a fixed list of extra projects.
class _TestHook implements PluginHook {
  final List<Project> extraProjects;

  _TestHook({this.extraProjects = const []});

  @override
  String get name => 'test-hook';

  @override
  String get fileGlob => '**/*.custom';

  @override
  Future<List<Project>> inferProjects(
    String workspaceRoot,
    List<String> matchedFiles,
  ) async {
    return extraProjects;
  }

  @override
  Future<Map<String, List<String>>> inferDependencies(
    List<Project> projects,
  ) async {
    return {};
  }

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

void _createWorkspace(String root, String name) {
  File(p.join(root, 'pubspec.yaml')).writeAsStringSync('''
name: $name
environment:
  sdk: ^3.11.1
workspace:
  - packages/*
''');
}

String _createPackage(String root, String name) {
  final pkgDir = p.join(root, 'packages', name);
  Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
  File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: $name
version: 0.1.0
resolution: workspace
environment:
  sdk: ^3.11.1
''');
  return pkgDir;
}
