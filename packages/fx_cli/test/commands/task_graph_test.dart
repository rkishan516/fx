import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('Task graph (fx graph --tasks)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_task_graph_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('shows task execution order', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      // Add targets with dependencies
      final pubspecPath = p.join(tempDir.path, 'pubspec.yaml');
      final content = File(pubspecPath).readAsStringSync();
      final editor = YamlEditor(content);
      editor.update(
        ['fx', 'targets'],
        {
          'build': {'executor': 'dart compile'},
          'test': {
            'executor': 'dart test',
            'dependsOn': ['build'],
          },
          'lint': {'executor': 'dart analyze'},
        },
      );
      File(pubspecPath).writeAsStringSync(editor.toString());

      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['graph', '--tasks', '--workspace', tempDir.path]);
      } finally {
        Directory.current = prevDir;
      }

      final out = output.toString();
      expect(out, contains('Task Execution Graph'));
      expect(out, contains('test'));
      expect(out, contains('build'));
      expect(out, contains('depends on'));
    });

    test('shows default targets from init', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['graph', '--tasks', '--workspace', tempDir.path]);
      } finally {
        Directory.current = prevDir;
      }

      final out = output.toString();
      expect(out, contains('Task Execution Graph'));
      expect(out, contains('Execution order'));
    });
  });
}
