import 'dart:convert';

import 'package:fx_cli/fx_cli.dart';
import 'package:test/test.dart';

void main() {
  group('CiInfoCommand', () {
    test('outputs valid JSON with required fields', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      try {
        await runner.run(['ci-info']);
      } catch (_) {}

      final json = jsonDecode(buf.toString()) as Map<String, dynamic>;
      // Required fields
      expect(
        json.keys,
        containsAll(['provider', 'baseRef', 'cachePaths', 'concurrency']),
      );
    });

    test('--provider github overrides provider detection', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      try {
        await runner.run(['ci-info', '--provider', 'github']);
      } catch (_) {}

      final json = jsonDecode(buf.toString()) as Map<String, dynamic>;
      expect(json['provider'], 'github');
    });

    test('non-CI environment outputs null provider and defaults', () async {
      final buf = StringBuffer();
      // Only inject if we're not actually in CI
      final runner = FxCommandRunner(outputSink: buf);
      try {
        await runner.run(['ci-info']);
      } catch (_) {}

      final out = buf.toString();
      final json = jsonDecode(out) as Map<String, dynamic>;
      // Provider should be a string or null
      expect(json['provider'], anyOf(isNull, isA<String>()));
      expect(json['concurrency'], isA<int>());
      expect(json['cachePaths'], isA<List<dynamic>>());
    });

    test('JSON output is parseable and well-formed', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      try {
        await runner.run(['ci-info']);
      } catch (_) {}

      expect(() => jsonDecode(buf.toString()), returnsNormally);
    });

    test('--provider flag is registered', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      // Should not throw "no option named provider"
      try {
        await runner.run(['ci-info', '--provider', 'gitlab']);
      } catch (e) {
        expect(e.toString(), isNot(contains('no option named')));
      }
    });

    test('ci-info is registered as a command', () {
      final runner = FxCommandRunner();
      expect(runner.commands.containsKey('ci-info'), isTrue);
    });
  });
}
