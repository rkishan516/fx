import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:test/test.dart';

void main() {
  group('PluginCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_plugin_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('lists built-in generators', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);
      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['plugin', 'list', '--workspace', tempDir.path]);
      } finally {
        Directory.current = prevDir;
      }

      final out = output.toString();
      expect(out, contains('Built-in generators'));
      expect(out, contains('dart_package'));
      expect(out, contains('flutter_app'));
    });

    test('shows no plugins configured message', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);
      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['plugin', 'list', '--workspace', tempDir.path]);
      } finally {
        Directory.current = prevDir;
      }

      expect(output.toString(), contains('No plugin paths configured'));
    });

    test('is registered as command', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('plugin'));
    });

    test(
      'plugin list shows Configured hook plugins section when pluginConfigs present',
      () async {
        // Write workspace directly with plugins section
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: test_ws
publish_to: none
environment:
  sdk: ^3.11.1
workspace:
  - packages/pkg_a
fx:
  packages:
    - packages/*
  plugins:
    - plugin: my_hook
      capabilities:
        - inference
''');
        Directory('${tempDir.path}/packages/pkg_a').createSync(recursive: true);
        File('${tempDir.path}/packages/pkg_a/pubspec.yaml').writeAsStringSync(
          '''
name: pkg_a
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''',
        );

        final output = StringBuffer();
        final runner = FxCommandRunner(outputSink: output);
        try {
          await runner.run(['plugin', 'list', '--workspace', tempDir.path]);
        } catch (_) {}

        final out = output.toString();
        expect(out, contains('my_hook'));
        expect(out, contains('inference'));
      },
    );

    test('plugin list does not crash for unknown hook plugin', () async {
      // Write workspace with an unknown plugin
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: test_ws
publish_to: none
environment:
  sdk: ^3.11.1
fx:
  packages:
    - packages/*
  plugins:
    - plugin: unknown_hook
''');
      Directory('${tempDir.path}/packages').createSync(recursive: true);

      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);
      // Should not throw
      await expectLater(
        runner.run(['plugin', 'list', '--workspace', tempDir.path]),
        completes,
      );
    });
  });
}
