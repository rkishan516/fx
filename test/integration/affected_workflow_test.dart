import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Integration test: `fx affected` identifies changed projects via git diff.
void main() {
  group('affected workflow', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_integration_affected_',
      );
      await _createWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('fx affected lists projects when all files changed', () async {
      // Mock git diff returning a file in pkg_a
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.arguments.contains('--name-only')) {
            return ProcessResult(
              exitCode: 0,
              stdout: 'packages/pkg_a/lib/src/pkg_a.dart',
              stderr: '',
            );
          }
          if (call.arguments.contains('--others')) {
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final output = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: output,
        processRunner: mockRunner,
      );

      await runner.run(['affected', '--workspace', workspaceDir.path]);

      expect(
        output.toString(),
        contains('pkg_a'),
        reason: 'pkg_a changed so it should be affected',
      );
    });

    test('fx affected does not list unchanged projects', () async {
      // Only pkg_a has changes
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.arguments.contains('--name-only')) {
            return ProcessResult(
              exitCode: 0,
              stdout: 'packages/pkg_a/lib/src/pkg_a.dart',
              stderr: '',
            );
          }
          if (call.arguments.contains('--others')) {
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final output = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: output,
        processRunner: mockRunner,
      );

      await runner.run(['affected', '--workspace', workspaceDir.path]);

      expect(
        output.toString(),
        isNot(contains('pkg_b')),
        reason: 'pkg_b was not changed',
      );
    });

    test('fx affected --target runs task on affected projects', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          if (call.arguments.contains('--name-only')) {
            return ProcessResult(
              exitCode: 0,
              stdout: 'packages/pkg_a/lib/src/pkg_a.dart',
              stderr: '',
            );
          }
          if (call.arguments.contains('--others')) {
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      await runner.run([
        'affected',
        '--target=test',
        '--workspace',
        workspaceDir.path,
      ]);

      final testCalls = calls
          .where((c) => c.arguments.contains('test'))
          .toList();
      expect(
        testCalls,
        isNotEmpty,
        reason: 'test should run on affected pkg_a',
      );
      // Should only run for pkg_a
      for (final call in testCalls) {
        expect(call.workingDirectory, contains('pkg_a'));
      }
    });

    test('fx affected with no changes produces empty output', () async {
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.arguments.contains('--name-only') ||
              call.arguments.contains('--others')) {
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final output = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: output,
        processRunner: mockRunner,
      );

      await runner.run(['affected', '--workspace', workspaceDir.path]);

      // No affected projects — output should not contain pkg names
      expect(output.toString(), isNot(contains('pkg_a')));
      expect(output.toString(), isNot(contains('pkg_b')));
    });
  });
}

Future<void> _createWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: affected_test_ws
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

  for (final name in ['pkg_a', 'pkg_b']) {
    final dir = Directory(p.join(root, 'packages', name));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('''
name: $name
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');
    // Create a source file so affected detection has a path to match
    final libDir = Directory(p.join(dir.path, 'lib', 'src'));
    await libDir.create(recursive: true);
    await File(p.join(libDir.path, '$name.dart')).writeAsString('// $name\n');
  }
}
