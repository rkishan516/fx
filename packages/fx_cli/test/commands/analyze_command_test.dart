import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AnalyzeCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_analyze_test_');
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('runs dart analyze on all packages', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(
            exitCode: 0,
            stdout: 'No issues found!',
            stderr: '',
          );
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['analyze', '--workspace', workspaceDir.path]);

      final analyzeCalls = calls
          .where((c) => c.arguments.contains('analyze'))
          .toList();
      expect(analyzeCalls, isNotEmpty);
    });

    test('exits with 0 when no issues found', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 0, stdout: 'No issues found!', stderr: ''),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      await expectLater(
        runner.run(['analyze', '--workspace', workspaceDir.path]),
        completes,
      );
    });

    test('exits with 1 when analyzer reports issues', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 1, stdout: '', stderr: '1 error found.'),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      bool threw = false;
      try {
        await runner.run(['analyze', '--workspace', workspaceDir.path]);
      } on ProcessExit catch (e) {
        threw = e.exitCode == 1;
      }

      expect(threw, isTrue);
    });

    test('prints summary of results', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 0, stdout: 'No issues found!', stderr: ''),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['analyze', '--workspace', workspaceDir.path]);

      expect(buffer.toString(), contains('pkg_a'));
    });

    test('analyze runs on each package directory', () async {
      // Create workspace with 2 packages
      final multiDir = await Directory.systemTemp.createTemp(
        'fx_analyze_multi_',
      );
      await File(p.join(multiDir.path, 'pubspec.yaml')).writeAsString('''
name: multi_ws
publish_to: none
environment:
  sdk: ^3.11.1
workspace:
  - packages/pkg_x
  - packages/pkg_y
fx:
  packages:
    - packages/*
  targets:
    analyze:
      executor: dart analyze
''');
      for (final name in ['pkg_x', 'pkg_y']) {
        final dir = Directory(p.join(multiDir.path, 'packages', name));
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

      final workingDirs = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          workingDirs.add(p.basename(call.workingDirectory));
          return ProcessResult(
            exitCode: 0,
            stdout: 'No issues found!',
            stderr: '',
          );
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );
      await runner.run(['analyze', '--workspace', multiDir.path]);

      expect(workingDirs, containsAll(['pkg_x', 'pkg_y']));
      await multiDir.delete(recursive: true);
    });

    test('partial failure reports correct exit code', () async {
      int callIdx = 0;
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          callIdx++;
          if (callIdx == 1) {
            return ProcessResult(
              exitCode: 0,
              stdout: 'No issues found!',
              stderr: '',
            );
          }
          return ProcessResult(exitCode: 1, stdout: '', stderr: '2 errors');
        },
      );

      // Need workspace with 2 packages for partial failure
      final multiDir = await Directory.systemTemp.createTemp(
        'fx_analyze_partial_',
      );
      await File(p.join(multiDir.path, 'pubspec.yaml')).writeAsString('''
name: multi_ws
publish_to: none
environment:
  sdk: ^3.11.1
workspace:
  - packages/ok_pkg
  - packages/bad_pkg
fx:
  packages:
    - packages/*
  targets:
    analyze:
      executor: dart analyze
''');
      for (final name in ['ok_pkg', 'bad_pkg']) {
        final dir = Directory(p.join(multiDir.path, 'packages', name));
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

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      bool threw = false;
      try {
        await runner.run(['analyze', '--workspace', multiDir.path]);
      } on ProcessExit catch (e) {
        threw = e.exitCode == 1;
      }

      expect(threw, isTrue);
      await multiDir.delete(recursive: true);
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
    analyze:
      executor: dart analyze
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
}
