import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Integration test: `fx run` caches results and restores them on second run.
void main() {
  group('cache workflow', () {
    late Directory workspaceDir;
    late Directory cacheDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_integration_cache_',
      );
      cacheDir = await Directory.systemTemp.createTemp('fx_cache_');
      await _createWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
      await cacheDir.delete(recursive: true);
    });

    test('second run restores from cache (executor not called)', () async {
      int callCount = 0;
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          callCount++;
          return ProcessResult(
            exitCode: 0,
            stdout: 'All tests passed!',
            stderr: '',
          );
        },
      );

      final runner1 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runner1.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);
      expect(callCount, equals(1), reason: 'first run executes the task');

      // Second run with same cache directory — should hit cache
      final runner2 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runner2.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);
      expect(
        callCount,
        equals(1),
        reason: 'second run should use cache, not call executor again',
      );
    });

    test('--skip-cache bypasses cache and re-executes', () async {
      int callCount = 0;
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          callCount++;
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );

      // First run — populates cache
      final runner1 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runner1.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // Second run with --skip-cache — should re-execute
      final runner2 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runner2.run([
        'run',
        'pkg_a',
        'test',
        '--skip-cache',
        '--workspace',
        workspaceDir.path,
      ]);
      expect(
        callCount,
        equals(2),
        reason: '--skip-cache should force re-execution',
      );
    });

    test('fx cache status reports cache entry count', () async {
      // Populate cache with one entry
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: 'ok', stderr: ''),
      );

      final runRunner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runRunner.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // Check cache status
      final output = StringBuffer();
      final cacheRunner = FxCommandRunner(
        outputSink: output,
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await cacheRunner.run(['cache', 'status']);

      expect(
        output.toString(),
        contains('1'),
        reason: 'should report 1 cached entry',
      );
    });

    test('fx cache clear removes all entries', () async {
      // Populate cache
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: 'ok', stderr: ''),
      );

      final runRunner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runRunner.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);

      // Clear cache
      final clearRunner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await clearRunner.run(['cache', 'clear']);

      // After clear, second run should execute again
      int callCount = 0;
      final mockRunner2 = MockProcessRunner(
        onRun: (call) {
          callCount++;
          return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
        },
      );
      final runRunner2 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner2,
        cacheDir: cacheDir.path,
      );
      await runRunner2.run([
        'run',
        'pkg_a',
        'test',
        '--workspace',
        workspaceDir.path,
      ]);
      expect(
        callCount,
        equals(1),
        reason: 'after clear, cache is empty so executor runs again',
      );
    });
  });
}

Future<void> _createWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: cache_test_ws
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

  final pkgDir = Directory(p.join(root, 'packages', 'pkg_a'));
  await pkgDir.create(recursive: true);
  await File(p.join(pkgDir.path, 'pubspec.yaml')).writeAsString('''
name: pkg_a
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');
  final libDir = Directory(p.join(pkgDir.path, 'lib'));
  await libDir.create(recursive: true);
  await File(p.join(libDir.path, 'pkg_a.dart')).writeAsString('// pkg_a\n');
}
