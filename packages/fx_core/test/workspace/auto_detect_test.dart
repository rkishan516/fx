import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Auto-detect mode (no fx: config)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_autodetect_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'loads workspace from pubspec.yaml with workspace: but no fx:',
      () async {
        // Root pubspec with workspace members but no fx: section
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/core
  - packages/app
''');

        // Create core package
        final coreDir = p.join(tempDir.path, 'packages', 'core');
        Directory(p.join(coreDir, 'lib')).createSync(recursive: true);
        File(p.join(coreDir, 'pubspec.yaml')).writeAsStringSync('''
name: core
version: 0.1.0
environment:
  sdk: ^3.11.1
''');

        // Create app package depending on core
        final appDir = p.join(tempDir.path, 'packages', 'app');
        Directory(p.join(appDir, 'lib')).createSync(recursive: true);
        File(p.join(appDir, 'pubspec.yaml')).writeAsStringSync('''
name: app
version: 0.1.0
environment:
  sdk: ^3.11.1
dependencies:
  core:
    path: ../core
''');

        final workspace = await WorkspaceLoader.load(tempDir.path);

        expect(workspace.projects, hasLength(2));
        expect(
          workspace.projects.map((p) => p.name),
          containsAll(['core', 'app']),
        );

        // Should have auto-inferred default targets
        final coreProject = workspace.projects.firstWhere(
          (p) => p.name == 'core',
        );
        expect(coreProject.targets, contains('test'));
        expect(coreProject.targets, contains('analyze'));
        expect(coreProject.targets['test']!.executor, contains('test'));
        expect(coreProject.targets['analyze']!.executor, contains('analyze'));
      },
    );

    test('auto-detect uses workspace: globs as package patterns', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/*
''');

      final pkgDir = p.join(tempDir.path, 'packages', 'utils');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: utils
version: 0.1.0
environment:
  sdk: ^3.11.1
''');

      final workspace = await WorkspaceLoader.load(tempDir.path);

      expect(workspace.projects, hasLength(1));
      expect(workspace.projects.first.name, 'utils');
    });

    test('auto-detect infers format target', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/lib_a
''');

      final pkgDir = p.join(tempDir.path, 'packages', 'lib_a');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: lib_a
version: 0.1.0
environment:
  sdk: ^3.11.1
''');

      final workspace = await WorkspaceLoader.load(tempDir.path);
      final project = workspace.projects.first;

      expect(project.targets, contains('format'));
      expect(project.targets['format']!.executor, 'dart format .');
    });

    test('fx: config takes priority over auto-detect', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/core

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: flutter test
''');

      final pkgDir = p.join(tempDir.path, 'packages', 'core');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: core
version: 0.1.0
environment:
  sdk: ^3.11.1
''');

      final workspace = await WorkspaceLoader.load(tempDir.path);
      final project = workspace.projects.first;

      // Should use the explicit fx: config, not auto-detect defaults
      expect(project.targets['test']!.executor, 'flutter test');
    });
  });
}
