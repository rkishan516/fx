import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FormatCheckCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_format_check_');
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('is registered as format:check', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('format:check'));
    });

    test('exits 0 when all files are formatted', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await expectLater(
        runner.run(['format:check', '--workspace', workspaceDir.path]),
        completes,
      );
      expect(buffer.toString(), contains('properly formatted'));
    });

    test('exits 1 when formatting changes needed', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 1, stdout: '', stderr: ''),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      bool threw = false;
      try {
        await runner.run(['format:check', '--workspace', workspaceDir.path]);
      } on ProcessExit catch (e) {
        threw = e.exitCode == 1;
      }
      expect(threw, isTrue);
    });

    test('uses --output=none --set-exit-if-changed flags', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );
      await runner.run(['format:check', '--workspace', workspaceDir.path]);

      final formatCalls = calls
          .where((c) => c.arguments.contains('format'))
          .toList();
      expect(formatCalls, isNotEmpty);
      expect(formatCalls.first.arguments, contains('--output=none'));
      expect(formatCalls.first.arguments, contains('--set-exit-if-changed'));
    });
  });

  group('SyncCheckCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_sync_check_');
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('is registered as sync:check', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('sync:check'));
    });

    test('exits 0 when workspace is in sync', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      await runner.run([
        'init',
        '--name',
        'test_ws',
        '--dir',
        workspaceDir.path,
      ]);

      final pkgDir = p.join(workspaceDir.path, 'packages', 'core');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: core
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');
      File(p.join(workspaceDir.path, 'pubspec.lock')).writeAsStringSync('');

      buffer.clear();
      await runner.run(['sync:check', '--workspace', workspaceDir.path]);

      expect(buffer.toString(), contains('in sync'));
    });

    test('exits 1 when workspace has issues', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      await runner.run([
        'init',
        '--name',
        'test_ws',
        '--dir',
        workspaceDir.path,
      ]);

      // Create package WITHOUT resolution: workspace
      final pkgDir = p.join(workspaceDir.path, 'packages', 'bad');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: bad
version: 0.1.0
environment:
  sdk: ^3.11.1
''');
      File(p.join(workspaceDir.path, 'pubspec.lock')).writeAsStringSync('');

      buffer.clear();
      bool threw = false;
      try {
        await runner.run(['sync:check', '--workspace', workspaceDir.path]);
      } on ProcessExit catch (e) {
        threw = e.exitCode == 1;
      }
      expect(threw, isTrue);
      expect(buffer.toString(), contains('OUT OF SYNC'));
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
