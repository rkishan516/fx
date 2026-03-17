import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('Root-level scripts', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_root_scripts_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('parses scripts from fx config', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      // Add scripts to the fx config in pubspec.yaml
      final pubspecPath = p.join(tempDir.path, 'pubspec.yaml');
      final content = File(pubspecPath).readAsStringSync();
      final editor = YamlEditor(content);
      editor.update(
        ['fx', 'scripts'],
        {'hello': 'echo hello-world', 'check': 'dart analyze'},
      );
      File(pubspecPath).writeAsStringSync(editor.toString());

      output.clear();

      // Run the root script
      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['run', ':hello', '--workspace', tempDir.path]);
      } finally {
        Directory.current = prevDir;
      }

      expect(output.toString(), contains('hello-world'));
    });

    test('errors on unknown root script', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await expectLater(
          runner.run(['run', ':nonexistent', '--workspace', tempDir.path]),
          throwsA(isA<Exception>()),
        );
      } finally {
        Directory.current = prevDir;
      }
    });
  });
}
