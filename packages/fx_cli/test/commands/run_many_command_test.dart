import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('RunManyCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_run_many_test_');
      await _createTwoPackageWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('runs target on all projects', () async {
      final executedProjects = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          // Working dir tells us which project this ran for
          executedProjects.add(p.basename(call.workingDirectory));
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      expect(executedProjects, containsAll(['pkg_a', 'pkg_b']));
    });

    test('--projects limits execution to specified projects', () async {
      final executedProjects = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executedProjects.add(p.basename(call.workingDirectory));
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target',
        'test',
        '--projects',
        'pkg_a',
        '--workspace',
        workspaceDir.path,
      ]);

      expect(executedProjects, contains('pkg_a'));
      expect(executedProjects, isNot(contains('pkg_b')));
    });

    test('respects dependency order', () async {
      final executionOrder = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executionOrder.add(p.basename(call.workingDirectory));
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // pkg_b depends on pkg_a, so pkg_a must run first
      final pkgAIdx = executionOrder.indexOf('pkg_a');
      final pkgBIdx = executionOrder.indexOf('pkg_b');
      expect(pkgAIdx, lessThan(pkgBIdx));
    });

    test('prints summary table at end', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: 'ok', stderr: ''),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      final output = buffer.toString();
      expect(output, contains('pkg_a'));
      expect(output, contains('pkg_b'));
    });

    test('throws ProcessExit when any project fails', () async {
      int callIdx = 0;
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          callIdx++;
          // First project succeeds, second fails
          if (callIdx == 1) {
            return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
          }
          return ProcessResult(exitCode: 1, stdout: '', stderr: 'fail');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      int? exitCode;
      try {
        await runner.run([
          'run-many',
          '--target',
          'test',
          '--workspace',
          workspaceDir.path,
        ]);
      } on ProcessExit catch (e) {
        exitCode = e.exitCode;
      }

      expect(exitCode, equals(1));
    });

    test('--projects with unknown project name is handled', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: 'ok', stderr: ''),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      // Should still complete (unknown projects are silently skipped or warned)
      await expectLater(
        runner.run([
          'run-many',
          '--target',
          'test',
          '--projects',
          'nonexistent',
          '--workspace',
          workspaceDir.path,
        ]),
        completes,
      );
    });

    test('--output-style tui uses compact icons', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: 'ok', stderr: ''),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target',
        'test',
        '--output-style',
        'tui',
        '--workspace',
        workspaceDir.path,
      ]);

      final output = buffer.toString();
      // TUI mode uses check-mark icons and compact summary
      expect(output, contains('✓'));
      expect(output, contains('passed'));
    });

    test('runs each project exactly once', () async {
      final executedProjects = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executedProjects.add(p.basename(call.workingDirectory));
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      await runner.run([
        'run-many',
        '--target',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // Each project should appear exactly once
      expect(executedProjects.where((p) => p == 'pkg_a').length, equals(1));
      expect(executedProjects.where((p) => p == 'pkg_b').length, equals(1));
    });
  });
}

Future<void> _createTwoPackageWorkspace(String root) async {
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
      inputs:
        - lib/**
''');

  final pkgADir = Directory(p.join(root, 'packages', 'pkg_a'));
  await pkgADir.create(recursive: true);
  await File(p.join(pkgADir.path, 'pubspec.yaml')).writeAsString('''
name: pkg_a
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.11.1
''');

  final pkgBDir = Directory(p.join(root, 'packages', 'pkg_b'));
  await pkgBDir.create(recursive: true);
  await File(p.join(pkgBDir.path, 'pubspec.yaml')).writeAsString('''
name: pkg_b
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.11.1

dependencies:
  pkg_a:
    path: ../pkg_a
''');

  for (final pkg in ['pkg_a', 'pkg_b']) {
    final libDir = Directory(p.join(root, 'packages', pkg, 'lib'));
    await libDir.create();
    await File(p.join(libDir.path, '$pkg.dart')).writeAsString('library $pkg;');
  }
}
