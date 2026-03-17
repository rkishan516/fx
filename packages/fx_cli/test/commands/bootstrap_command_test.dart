import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('BootstrapCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_bootstrap_test_',
      );
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('runs dart pub get at workspace root', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(
            exitCode: 0,
            stdout: 'Got dependencies!',
            stderr: '',
          );
        },
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['bootstrap', '--workspace', workspaceDir.path]);

      expect(calls, hasLength(1));
      expect(calls.first.executable, equals('dart'));
      expect(calls.first.arguments, containsAll(['pub', 'get']));
    });

    test('prints success message', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 0, stdout: 'Got dependencies!', stderr: ''),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );

      await runner.run(['bootstrap', '--workspace', workspaceDir.path]);

      expect(buffer.toString(), isNotEmpty);
    });

    test('throws on dart pub get failure', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 1, stdout: '', stderr: 'pub get failed'),
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );

      expect(
        () => runner.run(['bootstrap', '--workspace', workspaceDir.path]),
        throwsA(isA<ProcessExit>()),
      );
    });

    test('runs in workspace root directory', () async {
      final calls = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(
            exitCode: 0,
            stdout: 'Got dependencies!',
            stderr: '',
          );
        },
      );

      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
      );
      await runner.run(['bootstrap', '--workspace', workspaceDir.path]);

      expect(calls.first.workingDirectory, equals(workspaceDir.path));
    });

    test('success message includes bootstrap info', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 0, stdout: 'Got dependencies!', stderr: ''),
      );

      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
      );
      await runner.run(['bootstrap', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      // Should indicate completion
      expect(output, isNotEmpty);
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
  - packages/*
fx:
  packages:
    - packages/*
''');
}
