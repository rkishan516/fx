import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('RepairCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_repair_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('reports healthy workspace', () async {
      // Create a valid workspace
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      // Create a package with proper fields
      final pkgDir = p.join(tempDir.path, 'packages', 'core');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: core
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');

      output.clear();

      // Change to workspace dir and run repair
      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['repair']);
      } finally {
        Directory.current = prevDir;
      }

      expect(output.toString(), contains('healthy'));
    });

    test('is registered as command', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('repair'));
    });
  });
}
