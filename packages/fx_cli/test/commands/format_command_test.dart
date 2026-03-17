import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FormatCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_format_test_');
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('runs dart format on all packages', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['format', '--workspace', workspaceDir.path]);

      // Should have invoked dart format for each package
      final formatCalls = calls
          .where((c) => c.arguments.contains('format'))
          .toList();
      expect(formatCalls, isNotEmpty);
    });

    test('--check exits with 1 when format changes needed', () async {
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          // Simulate format finding changes (changed 1 file)
          return ProcessResult(
            exitCode: 0,
            stdout: 'Changed pkg_a/lib/foo.dart',
            stderr: '',
          );
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      bool threw = false;
      try {
        await runner.run([
          'format',
          '--check',
          '--workspace',
          workspaceDir.path,
        ]);
      } on ProcessExit catch (e) {
        threw = e.exitCode == 1;
      }

      expect(threw, isTrue);
    });

    test('--check exits with 0 when no format changes needed', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 0, stdout: 'No changes made.', stderr: ''),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      await expectLater(
        runner.run(['format', '--check', '--workspace', workspaceDir.path]),
        completes,
      );
    });

    test('format runs on each package directory', () async {
      // Create workspace with 2 packages
      final multiDir = await Directory.systemTemp.createTemp(
        'fx_format_multi_',
      );
      await File(p.join(multiDir.path, 'pubspec.yaml')).writeAsString('''
name: multi_ws
publish_to: none
environment:
  sdk: ^3.11.1
workspace:
  - packages/pkg_a
  - packages/pkg_b
fx:
  packages:
    - packages/*
''');
      for (final name in ['pkg_a', 'pkg_b']) {
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
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );
      await runner.run(['format', '--workspace', multiDir.path]);

      expect(workingDirs, containsAll(['pkg_a', 'pkg_b']));
      await multiDir.delete(recursive: true);
    });

    test('prints output per package', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(
          exitCode: 0,
          stdout: 'Formatted 3 files.',
          stderr: '',
        ),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['format', '--workspace', workspaceDir.path]);

      expect(buffer.toString(), contains('pkg_a'));
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
    format:
      executor: dart format .
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
