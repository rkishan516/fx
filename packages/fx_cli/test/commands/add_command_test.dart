import 'package:args/command_runner.dart';
import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('AddCommand', () {
    test('is registered as a command', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('add'));
    });

    test('requires package name', () async {
      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: MockProcessRunner(
          onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ),
      );

      expect(() => runner.run(['add']), throwsA(isA<UsageException>()));
    });

    test('has --dev flag', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      final addCmd = runner.commands['add']!;
      expect(addCmd.argParser.options, contains('dev'));
    });
  });
}
