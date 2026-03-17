import 'dart:convert';
import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ListCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_list_test_');
      // Bootstrap a minimal workspace
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('outputs project names in text format', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['list', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      expect(output, contains('pkg_a'));
      expect(output, contains('pkg_b'));
    });

    test('--json outputs valid JSON array', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['list', '--json', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      final jsonData = jsonDecode(output) as List;
      expect(jsonData, isNotEmpty);

      final names = jsonData.map((e) => (e as Map)['name']).toList();
      expect(names, containsAll(['pkg_a', 'pkg_b']));
    });

    test('JSON output includes type field', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['list', '--json', '--workspace', workspaceDir.path]);

      final jsonData = jsonDecode(buffer.toString()) as List;
      for (final entry in jsonData) {
        expect((entry as Map).containsKey('type'), isTrue);
      }
    });

    test('JSON output includes path field', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['list', '--json', '--workspace', workspaceDir.path]);

      final jsonData = jsonDecode(buffer.toString()) as List;
      for (final entry in jsonData) {
        expect((entry as Map).containsKey('path'), isTrue);
      }
    });

    test('empty workspace lists no projects', () async {
      // Create a workspace with no packages
      final emptyDir = await Directory.systemTemp.createTemp('fx_list_empty_');
      await File(p.join(emptyDir.path, 'pubspec.yaml')).writeAsString('''
name: empty_ws
publish_to: none
environment:
  sdk: ^3.11.1
fx:
  packages:
    - packages/*
''');
      await Directory(p.join(emptyDir.path, 'packages')).create();

      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['list', '--json', '--workspace', emptyDir.path]);

      final jsonData = jsonDecode(buffer.toString()) as List;
      expect(jsonData, isEmpty);

      await emptyDir.delete(recursive: true);
    });

    test('text output contains all project names', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['list', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      // Both packages should appear in text output
      expect(output, contains('pkg_a'));
      expect(output, contains('pkg_b'));
    });

    test('JSON entries have correct name values', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['list', '--json', '--workspace', workspaceDir.path]);

      final jsonData = jsonDecode(buffer.toString()) as List;
      final names = jsonData.map((e) => (e as Map)['name'] as String).toSet();
      expect(names, equals({'pkg_a', 'pkg_b'}));
    });
  });
}

Future<void> _createMinimalWorkspace(String root) async {
  // Root pubspec.yaml with fx: section
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: test_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/pkg_a
  - packages/pkg_b

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
''');

  // Create packages
  for (final name in ['pkg_a', 'pkg_b']) {
    final pkgDir = Directory(p.join(root, 'packages', name));
    await pkgDir.create(recursive: true);
    await File(p.join(pkgDir.path, 'pubspec.yaml')).writeAsString('''
name: $name
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.11.1
''');
  }
}
