import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GenerateCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_generate_test_');
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('generates dart_package with correct files', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      await runner.run([
        'generate',
        'dart_package',
        'my_new_lib',
        '--workspace',
        workspaceDir.path,
        '--dry-run',
      ]);

      final output = buffer.toString();
      expect(output, contains('my_new_lib'));
      expect(output, contains('pubspec.yaml'));
    });

    test('creates package directory when not dry-run', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      await runner.run([
        'generate',
        'dart_package',
        'my_lib',
        '--workspace',
        workspaceDir.path,
        '--directory',
        p.join(workspaceDir.path, 'packages'),
      ]);

      final packageDir = Directory(
        p.join(workspaceDir.path, 'packages', 'my_lib'),
      );
      expect(packageDir.existsSync(), isTrue);

      final pubspec = File(p.join(packageDir.path, 'pubspec.yaml'));
      expect(pubspec.existsSync(), isTrue);
    });

    test('generated pubspec.yaml contains correct package name', () async {
      final runner = FxCommandRunner(outputSink: StringBuffer());

      await runner.run([
        'generate',
        'dart_package',
        'awesome_pkg',
        '--workspace',
        workspaceDir.path,
        '--directory',
        p.join(workspaceDir.path, 'packages'),
      ]);

      final pubspec = File(
        p.join(workspaceDir.path, 'packages', 'awesome_pkg', 'pubspec.yaml'),
      );
      final content = await pubspec.readAsString();
      expect(content, contains('name: awesome_pkg'));
    });

    test('lists available generators with --list', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      await runner.run([
        'generate',
        '--list',
        '--workspace',
        workspaceDir.path,
      ]);

      final output = buffer.toString();
      expect(output, contains('dart_package'));
      expect(output, contains('flutter_package'));
      expect(output, contains('flutter_app'));
      expect(output, contains('dart_cli'));
    });

    test('shows error for unknown generator', () async {
      final runner = FxCommandRunner(outputSink: StringBuffer());

      bool threw = false;
      try {
        await runner.run([
          'generate',
          'nonexistent_gen',
          'my_pkg',
          '--workspace',
          workspaceDir.path,
        ]);
      } catch (_) {
        threw = true;
      }

      expect(threw, isTrue);
    });

    test('generates flutter_package with flutter dependency', () async {
      final runner = FxCommandRunner(outputSink: StringBuffer());

      await runner.run([
        'generate',
        'flutter_package',
        'my_widget',
        '--workspace',
        workspaceDir.path,
        '--directory',
        p.join(workspaceDir.path, 'packages'),
      ]);

      final pubspec = File(
        p.join(workspaceDir.path, 'packages', 'my_widget', 'pubspec.yaml'),
      );
      expect(pubspec.existsSync(), isTrue);
      final content = await pubspec.readAsString();
      expect(content, contains('name: my_widget'));
      expect(content, contains('flutter:'));
    });

    test('generates dart_cli with bin/main.dart', () async {
      final runner = FxCommandRunner(outputSink: StringBuffer());

      await runner.run([
        'generate',
        'dart_cli',
        'my_tool',
        '--workspace',
        workspaceDir.path,
        '--directory',
        p.join(workspaceDir.path, 'packages'),
      ]);

      final mainFile = File(
        p.join(workspaceDir.path, 'packages', 'my_tool', 'bin', 'main.dart'),
      );
      expect(mainFile.existsSync(), isTrue);
    });

    test('dry-run does not create files on disk', () async {
      final runner = FxCommandRunner(outputSink: StringBuffer());

      await runner.run([
        'generate',
        'dart_package',
        'phantom_pkg',
        '--workspace',
        workspaceDir.path,
        '--dry-run',
      ]);

      final packageDir = Directory(
        p.join(workspaceDir.path, 'packages', 'phantom_pkg'),
      );
      expect(packageDir.existsSync(), isFalse);
    });
  });
}

Future<void> _createMinimalWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: test_workspace
publish_to: none
environment:
  sdk: ^3.11.1
workspace:
  - packages/*
fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
''');

  await Directory(p.join(root, 'packages')).create(recursive: true);
}
