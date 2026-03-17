import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Integration test: `fx run` and `fx run-many` execute tasks on projects.
void main() {
  group('run workflow', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_integration_run_',
      );
      await _createWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('fx run executes target on named project', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      await runner.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      final testCalls = calls
          .where((c) => c.arguments.contains('test'))
          .toList();
      expect(testCalls, isNotEmpty, reason: 'dart test should be invoked');
    });

    test('fx run-many runs target on all projects', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target=test',
        '--workspace',
        workspaceDir.path,
      ]);

      final testCalls = calls
          .where((c) => c.arguments.contains('test'))
          .toList();
      expect(
        testCalls,
        hasLength(greaterThanOrEqualTo(2)),
        reason: 'should run test for each project',
      );
    });

    test('fx run exits non-zero when target fails', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 1, stdout: '', stderr: 'error'),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      bool threw = false;
      try {
        await runner.run([
          'run',
          'pkg_a',
          'test',
          '--workspace',
          workspaceDir.path,
        ]);
      } on ProcessExit catch (e) {
        threw = e.exitCode == 1;
      }
      expect(threw, isTrue);
    });

    test('fx run-many respects --projects filter', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target=test',
        '--projects=pkg_a',
        '--workspace',
        workspaceDir.path,
      ]);

      // Should only run for pkg_a
      expect(calls, hasLength(1));
      expect(calls.first.workingDirectory, endsWith('pkg_a'));
    });
  });
}

Future<void> _createWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: run_test_ws
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
  }
}
