import 'package:fx_cli/fx_cli.dart';
import 'package:test/test.dart';

void main() {
  group('FxCommandRunner', () {
    test('registers all expected commands', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      final commandNames = runner.commands.keys.toSet();

      expect(commandNames, contains('init'));
      expect(commandNames, contains('list'));
      expect(commandNames, contains('graph'));
      expect(commandNames, contains('run'));
      expect(commandNames, contains('run-many'));
      expect(commandNames, contains('affected'));
      expect(commandNames, contains('cache'));
      expect(commandNames, contains('generate'));
      expect(commandNames, contains('bootstrap'));
      expect(commandNames, contains('format'));
      expect(commandNames, contains('analyze'));
    });

    test('has correct executable name', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.executableName, equals('fx'));
    });

    test('has description', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.description, isNotEmpty);
    });

    test('constructs with default outputSink', () {
      // Should not throw
      final runner = FxCommandRunner();
      expect(runner, isNotNull);
    });

    test('--help does not throw', () async {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      // --help should complete without error
      expect(() => runner.run(['--help']), returnsNormally);
    });
  });
}
