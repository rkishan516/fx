import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:test/test.dart';

void main() {
  group('ExecCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_exec_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('runs command across all projects', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      // Create workspace with a package
      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);
      await runner.run([
        'generate',
        'dart_package',
        'my_pkg',
        '--workspace',
        tempDir.path,
      ]);

      // Run a simple command
      await runner.run([
        'exec',
        '--workspace',
        tempDir.path,
        '--',
        'echo',
        'hello',
      ]);

      final out = output.toString();
      expect(out, contains('Running "echo hello"'));
      expect(out, contains('my_pkg'));
    });

    test('is registered as command', () {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);
      // Check that the runner has the exec command registered
      expect(runner.commands.keys, contains('exec'));
    });

    test('requires command arguments', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      expect(
        () => runner.run(['exec', '--workspace', tempDir.path]),
        throwsA(anything),
      );
    });
  });
}
