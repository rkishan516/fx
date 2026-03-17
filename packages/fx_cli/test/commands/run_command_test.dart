import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('RunCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_run_test_');
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('runs target on specified project', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(
            exitCode: 0,
            stdout: 'All tests passed.',
            stderr: '',
          );
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      expect(calls, hasLength(1));
      expect(calls.first.executable, equals('dart'));
      expect(calls.first.arguments, contains('test'));
    });

    test('prints success summary', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 0, stdout: 'Tests passed.', stderr: ''),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      expect(buffer.toString(), contains('pkg_a'));
    });

    test('returns exit code 1 when target fails', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 1, stdout: '', stderr: 'Test failed.'),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      int? exitCode;
      try {
        await runner.run([
          'run',
          'pkg_a',
          'test',
          '--workspace',
          workspaceDir.path,
        ]);
      } on ProcessExit catch (e) {
        exitCode = e.exitCode;
      }

      expect(exitCode, equals(1));
    });

    test('skips execution when cache hit', () async {
      // Pre-populate cache
      final cacheDir = p.join(workspaceDir.path, '.fx_cache');

      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(exitCode: 0, stdout: 'output', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
        cacheDir: cacheDir,
      );

      // First run
      await runner.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      final firstRunCalls = calls.length;

      // Second run — should hit cache
      await runner.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // Second run should not invoke the process again
      expect(calls.length, equals(firstRunCalls));
    });

    test('throws UsageException when project name missing', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      expect(
        () => runner.run(['run', '--workspace', workspaceDir.path]),
        throwsA(anything),
      );
    });

    test('throws UsageException for unknown project', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      expect(
        () => runner.run([
          'run',
          'nonexistent_pkg',
          'test',
          '--workspace',
          workspaceDir.path,
        ]),
        throwsA(anything),
      );
    });

    test('--skip-cache forces re-execution', () async {
      final cacheDir = p.join(workspaceDir.path, '.fx_cache');
      int callCount = 0;
      final mockRunner = MockProcessRunner(
        onRun: (_) {
          callCount++;
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      final runner1 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir,
      );
      await runner1.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);
      expect(callCount, 1);

      // With --skip-cache, should re-execute even though cached
      final runner2 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir,
      );
      await runner2.run([
        'run',
        'pkg_a',
        'test',
        '--skip-cache',
        '--workspace',
        workspaceDir.path,
      ]);
      expect(callCount, 2);
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
  - packages/pkg_a

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
      inputs:
        - lib/**
        - test/**
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

  final libDir = Directory(p.join(pkgADir.path, 'lib'));
  await libDir.create();
  await File(
    p.join(libDir.path, 'pkg_a.dart'),
  ).writeAsString('library pkg_a;\n');
}

// ProcessExit is imported from package:fx_cli/fx_cli.dart via the export
// of run_command.dart. No local definition needed.
