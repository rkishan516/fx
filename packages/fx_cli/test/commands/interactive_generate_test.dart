import 'dart:async';

import 'package:fx_cli/fx_cli.dart';
import 'package:test/test.dart';

void main() {
  group('Interactive generate', () {
    test('generate command has interactive flag', () {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);
      final cmd = runner.commands['generate']!;
      expect(cmd.argParser.options, contains('interactive'));
    });

    test('Prompter.prompt reads from stream', () async {
      final output = StringBuffer();
      final controller = StreamController<String>();

      final prompter = Prompter(sink: output, input: controller.stream);

      final future = prompter.prompt('Name');
      controller.add('my_app');

      final result = await future;
      expect(result, equals('my_app'));
      expect(output.toString(), contains('Name:'));

      await controller.close();
    });

    test('Prompter.choose returns selected index', () async {
      final output = StringBuffer();
      final controller = StreamController<String>();

      final prompter = Prompter(sink: output, input: controller.stream);

      final future = prompter.choose('Pick one:', ['package', 'app', 'plugin']);
      controller.add('2');

      final result = await future;
      expect(result, equals(1)); // '2' → index 1

      final out = output.toString();
      expect(out, contains('Pick one:'));
      expect(out, contains('1) package'));
      expect(out, contains('2) app'));
      expect(out, contains('3) plugin'));

      await controller.close();
    });
  });
}
