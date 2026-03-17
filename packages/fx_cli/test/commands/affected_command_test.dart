import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AffectedCommand (no target)', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_affected_test_');
      await _createTwoPackageWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('lists affected projects when no --target given', () async {
      // Mock git to return pkg_a file as changed
      final pkgAFile = p.join(
        workspaceDir.path,
        'packages',
        'pkg_a',
        'lib',
        'pkg_a.dart',
      );

      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.executable == 'git') {
            if (call.arguments.contains('diff')) {
              return ProcessResult(exitCode: 0, stdout: pkgAFile, stderr: '');
            }
            if (call.arguments.contains('ls-files')) {
              return ProcessResult(exitCode: 0, stdout: '', stderr: '');
            }
          }
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['affected', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      // pkg_a is directly affected; pkg_b depends on pkg_a so also affected
      expect(output, contains('pkg_a'));
    });

    test('lists no projects when nothing changed', () async {
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.executable == 'git') {
            return ProcessResult(
              exitCode: 0,
              stdout: '',
              stderr: '',
            ); // no changed files
          }
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['affected', '--workspace', workspaceDir.path]);

      expect(buffer.toString(), contains('No affected projects'));
    });
  });

  group('AffectedCommand (with --target)', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_affected_run_test_',
      );
      await _createTwoPackageWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('runs target only on affected projects', () async {
      final pkgAFile = p.join(
        workspaceDir.path,
        'packages',
        'pkg_a',
        'lib',
        'pkg_a.dart',
      );

      final taskCalls = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.executable == 'git') {
            if (call.arguments.contains('diff')) {
              return ProcessResult(exitCode: 0, stdout: pkgAFile, stderr: '');
            }
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          // Task execution
          taskCalls.add(p.basename(call.workingDirectory));
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'affected',
        '--target',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // Both pkg_a and pkg_b (which depends on pkg_a) should be run
      expect(taskCalls, contains('pkg_a'));
      expect(taskCalls, contains('pkg_b'));
    });

    test('only leaf affected when dependency not changed', () async {
      // Only pkg_b changed directly — pkg_a should NOT be affected
      // Use relative path (as git diff --name-only returns)
      const pkgBRelFile = 'packages/pkg_b/lib/pkg_b.dart';

      final taskCalls = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.executable == 'git') {
            if (call.arguments.contains('diff')) {
              return ProcessResult(
                exitCode: 0,
                stdout: pkgBRelFile,
                stderr: '',
              );
            }
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          taskCalls.add(p.basename(call.workingDirectory));
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'affected',
        '--target',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // pkg_b is directly affected, pkg_a should NOT be affected
      // (nothing depends on pkg_b)
      expect(taskCalls, contains('pkg_b'));
      expect(taskCalls, isNot(contains('pkg_a')));
    });

    test('throws ProcessExit when affected target fails', () async {
      // Use relative path (as git diff --name-only returns)
      const pkgARelFile = 'packages/pkg_a/lib/pkg_a.dart';

      final mockRunner = MockProcessRunner(
        onRun: (call) {
          if (call.executable == 'git') {
            if (call.arguments.contains('diff')) {
              return ProcessResult(
                exitCode: 0,
                stdout: pkgARelFile,
                stderr: '',
              );
            }
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          return ProcessResult(exitCode: 1, stdout: '', stderr: 'test failed');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      int? exitCode;
      try {
        await runner.run([
          'affected',
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
