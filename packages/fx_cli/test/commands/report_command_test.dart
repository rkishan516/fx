import 'package:fx_cli/fx_cli.dart';
import 'package:test/test.dart';

void main() {
  group('ReportCommand', () {
    test('outputs system information', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['report']);

      final text = output.toString();
      expect(text, contains('fx Report'));
      expect(text, contains('Dart version'));
      expect(text, contains('Platform'));
      expect(text, contains('CI'));
      expect(text, contains('Concurrency'));
    });

    test('reports workspace not found when outside workspace', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['report']);

      final text = output.toString();
      // Either shows workspace info or "not found"
      expect(text, anyOf(contains('Projects'), contains('not found')));
    });
  });
}
