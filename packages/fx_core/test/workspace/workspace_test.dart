import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('Workspace', () {
    test('constructs with config and projects', () {
      final config = FxConfig.defaults();
      final projects = [
        Project(
          name: 'app',
          path: '/ws/apps/app',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
        ),
      ];
      final workspace = Workspace(
        rootPath: '/ws',
        config: config,
        projects: projects,
      );
      expect(workspace.rootPath, '/ws');
      expect(workspace.projects, hasLength(1));
      expect(workspace.projectByName('app'), isNotNull);
      expect(workspace.projectByName('missing'), isNull);
    });

    test('projectByName finds project', () {
      final workspace = Workspace(
        rootPath: '/ws',
        config: FxConfig.defaults(),
        projects: [
          Project(
            name: 'pkg_a',
            path: '/ws/packages/pkg_a',
            type: ProjectType.dartPackage,
            dependencies: [],
            targets: {},
          ),
          Project(
            name: 'pkg_b',
            path: '/ws/packages/pkg_b',
            type: ProjectType.dartPackage,
            dependencies: [],
            targets: {},
          ),
        ],
      );
      expect(workspace.projectByName('pkg_a')?.name, 'pkg_a');
      expect(workspace.projectByName('pkg_b')?.name, 'pkg_b');
      expect(workspace.projectByName('pkg_c'), isNull);
    });

    test('resolveExecutor returns flutter commands for flutter projects', () {
      final workspace = Workspace(
        rootPath: '/ws',
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'test': {'executor': 'dart test'},
            'analyze': {'executor': 'dart analyze'},
          },
        }),
        projects: [],
      );

      final dartProject = Project(
        name: 'dart_lib',
        path: '/ws/packages/dart_lib',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );
      final flutterApp = Project(
        name: 'flutter_app',
        path: '/ws/apps/flutter_app',
        type: ProjectType.flutterApp,
        dependencies: [],
        targets: {},
      );

      expect(workspace.resolveExecutor(dartProject, 'test'), 'dart test');
      expect(workspace.resolveExecutor(flutterApp, 'test'), 'flutter test');
      expect(
        workspace.resolveExecutor(flutterApp, 'analyze'),
        'flutter analyze',
      );
    });

    test('resolveExecutor returns project-level target override', () {
      final workspace = Workspace(
        rootPath: '/ws',
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'test': {'executor': 'dart test'},
          },
        }),
        projects: [],
      );

      final project = Project(
        name: 'special_pkg',
        path: '/ws/packages/special_pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {'test': Target(name: 'test', executor: 'custom_test_runner')},
      );

      expect(workspace.resolveExecutor(project, 'test'), 'custom_test_runner');
    });

    test('resolveExecutor returns empty string for unconfigured target', () {
      final workspace = Workspace(
        rootPath: '/ws',
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
        projects: [],
      );

      final project = Project(
        name: 'pkg',
        path: '/ws/packages/pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );

      expect(workspace.resolveExecutor(project, 'nonexistent'), isEmpty);
    });

    test('routeFlutterExecutor substitutes known dart commands', () {
      expect(Workspace.routeFlutterExecutor('dart test'), 'flutter test');
      expect(Workspace.routeFlutterExecutor('dart analyze'), 'flutter analyze');
      expect(Workspace.routeFlutterExecutor('dart pub get'), 'flutter pub get');
      expect(
        Workspace.routeFlutterExecutor('dart pub upgrade'),
        'flutter pub upgrade',
      );
    });

    test('routeFlutterExecutor preserves unknown commands', () {
      expect(Workspace.routeFlutterExecutor('custom_cmd'), 'custom_cmd');
      expect(Workspace.routeFlutterExecutor('dart format .'), 'dart format .');
    });

    test('toString includes root path and project count', () {
      final workspace = Workspace(
        rootPath: '/ws',
        config: FxConfig.defaults(),
        projects: [
          Project(
            name: 'a',
            path: '/ws/a',
            type: ProjectType.dartPackage,
            dependencies: [],
            targets: {},
          ),
        ],
      );
      expect(workspace.toString(), contains('/ws'));
      expect(workspace.toString(), contains('1 projects'));
    });

    test('projectByName with empty project list returns null', () {
      final workspace = Workspace(
        rootPath: '/ws',
        config: FxConfig.defaults(),
        projects: [],
      );
      expect(workspace.projectByName('anything'), isNull);
    });
  });
}
