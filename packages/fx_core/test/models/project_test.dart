import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('Project', () {
    test('constructs with required fields', () {
      final project = Project(
        name: 'my_lib',
        path: '/workspace/packages/my_lib',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );
      expect(project.name, 'my_lib');
      expect(project.path, '/workspace/packages/my_lib');
      expect(project.type, ProjectType.dartPackage);
      expect(project.dependencies, isEmpty);
      expect(project.targets, isEmpty);
    });

    test('constructs with all project types', () {
      expect(
        Project(
          name: 'a',
          path: '/a',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
        ).type,
        ProjectType.dartPackage,
      );
      expect(
        Project(
          name: 'b',
          path: '/b',
          type: ProjectType.flutterPackage,
          dependencies: [],
          targets: {},
        ).type,
        ProjectType.flutterPackage,
      );
      expect(
        Project(
          name: 'c',
          path: '/c',
          type: ProjectType.flutterApp,
          dependencies: [],
          targets: {},
        ).type,
        ProjectType.flutterApp,
      );
      expect(
        Project(
          name: 'd',
          path: '/d',
          type: ProjectType.dartCli,
          dependencies: [],
          targets: {},
        ).type,
        ProjectType.dartCli,
      );
    });

    test('copyWith preserves unchanged fields', () {
      final original = Project(
        name: 'lib',
        path: '/path',
        type: ProjectType.dartPackage,
        dependencies: ['dep_a'],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
      );
      final copy = original.copyWith(name: 'new_lib');
      expect(copy.name, 'new_lib');
      expect(copy.path, '/path');
      expect(copy.dependencies, ['dep_a']);
    });

    test('isFlutter returns true for flutter types', () {
      final pkg = Project(
        name: 'a',
        path: '/',
        type: ProjectType.flutterPackage,
        dependencies: [],
        targets: {},
      );
      final app = Project(
        name: 'b',
        path: '/',
        type: ProjectType.flutterApp,
        dependencies: [],
        targets: {},
      );
      final dart = Project(
        name: 'c',
        path: '/',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );
      expect(pkg.isFlutter, isTrue);
      expect(app.isFlutter, isTrue);
      expect(dart.isFlutter, isFalse);
    });

    test('toJson / fromJson round-trips correctly', () {
      final project = Project(
        name: 'my_lib',
        path: '/workspace/packages/my_lib',
        type: ProjectType.dartPackage,
        dependencies: ['core', 'utils'],
        targets: {
          'test': Target(
            name: 'test',
            executor: 'dart test',
            inputs: ['lib/**', 'test/**'],
            dependsOnEntries: [DependsOnEntry(target: 'build')],
          ),
        },
      );
      final json = project.toJson();
      final restored = Project.fromJson(json);
      expect(restored.name, project.name);
      expect(restored.path, project.path);
      expect(restored.type, project.type);
      expect(restored.dependencies, project.dependencies);
      expect(restored.targets['test']?.executor, 'dart test');
    });
  });

  group('Target', () {
    test('constructs with defaults', () {
      final target = Target(name: 'build', executor: 'dart compile');
      expect(target.name, 'build');
      expect(target.executor, 'dart compile');
      expect(target.inputs, isEmpty);
      expect(target.dependsOn, isEmpty);
    });

    test('toJson / fromJson round-trips', () {
      final target = Target(
        name: 'test',
        executor: 'dart test',
        inputs: ['lib/**'],
        dependsOnEntries: [DependsOnEntry(target: 'build')],
      );
      final json = target.toJson();
      final restored = Target.fromJson(json);
      expect(restored.name, target.name);
      expect(restored.executor, target.executor);
      expect(restored.inputs, target.inputs);
      expect(restored.dependsOn, target.dependsOn);
    });
  });
}
