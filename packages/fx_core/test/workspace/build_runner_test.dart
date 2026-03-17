import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('build_runner integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_build_runner_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('auto-detects build_runner and adds build target', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/models

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
''');

      final pkgDir = p.join(tempDir.path, 'packages', 'models');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: models
version: 0.1.0
environment:
  sdk: ^3.11.1
dependencies:
  json_annotation: ^4.0.0
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.0.0
''');

      final workspace = await WorkspaceLoader.load(tempDir.path);
      final project = workspace.projects.first;

      expect(project.targets, contains('build'));
      expect(
        project.targets['build']!.executor,
        'dart run build_runner build --delete-conflicting-outputs',
      );
    });

    test('does not add build target when no build_runner dep', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/utils

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
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
      final project = workspace.projects.first;

      expect(project.targets, isNot(contains('build')));
    });

    test('explicit build target overrides auto-detected one', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/models

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
    build:
      executor: custom build command
''');

      final pkgDir = p.join(tempDir.path, 'packages', 'models');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: models
version: 0.1.0
environment:
  sdk: ^3.11.1
dev_dependencies:
  build_runner: ^2.4.0
''');

      final workspace = await WorkspaceLoader.load(tempDir.path);
      final project = workspace.projects.first;

      // Explicit workspace target takes precedence
      expect(project.targets['build']!.executor, 'custom build command');
    });

    test('PubspecParser detects build_runner dependency', () {
      final pubspec = PubspecParser.parse('''
name: models
version: 0.1.0
environment:
  sdk: ^3.11.1
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.0.0
''', path: 'test');

      expect(pubspec.hasBuildRunner, isTrue);
    });

    test('PubspecParser returns false when no build_runner', () {
      final pubspec = PubspecParser.parse('''
name: utils
version: 0.1.0
environment:
  sdk: ^3.11.1
''', path: 'test');

      expect(pubspec.hasBuildRunner, isFalse);
    });
  });
}
