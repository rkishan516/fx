import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('ImportCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_import_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('imports external package into workspace', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      // Create workspace
      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      // Create an external package to import
      final extDir = p.join(tempDir.path, '_external', 'my_pkg');
      Directory(p.join(extDir, 'lib')).createSync(recursive: true);
      File(p.join(extDir, 'pubspec.yaml')).writeAsStringSync('''
name: my_pkg
version: 1.0.0
environment:
  sdk: ^3.11.1
''');
      File(
        p.join(extDir, 'lib', 'my_pkg.dart'),
      ).writeAsStringSync('// my_pkg\n');

      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['import', extDir]);
      } finally {
        Directory.current = prevDir;
      }

      // Verify package was copied
      final imported = p.join(tempDir.path, 'packages', 'my_pkg');
      expect(Directory(imported).existsSync(), isTrue);
      expect(File(p.join(imported, 'lib', 'my_pkg.dart')).existsSync(), isTrue);

      // Verify resolution: workspace was added
      final pubContent = File(
        p.join(imported, 'pubspec.yaml'),
      ).readAsStringSync();
      final yaml = loadYaml(pubContent) as YamlMap;
      expect(yaml['resolution'].toString(), equals('workspace'));

      expect(output.toString(), contains('Imported'));
    });

    test('rejects non-existent source path', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await expectLater(
          runner.run(['import', '/nonexistent/path']),
          throwsA(isA<UsageException>()),
        );
      } finally {
        Directory.current = prevDir;
      }
    });

    test('--no-history skips git subtree', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      final extDir = p.join(tempDir.path, '_external2', 'simple_pkg');
      Directory(p.join(extDir, 'lib')).createSync(recursive: true);
      File(p.join(extDir, 'pubspec.yaml')).writeAsStringSync('''
name: simple_pkg
version: 1.0.0
environment:
  sdk: ^3.11.1
''');

      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['import', '--no-history', extDir]);
      } finally {
        Directory.current = prevDir;
      }

      final imported = p.join(tempDir.path, 'packages', 'simple_pkg');
      expect(Directory(imported).existsSync(), isTrue);
      // Should not mention git history
      expect(output.toString(), isNot(contains('git history')));
    });

    test('has branch and no-history flags', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      final cmd = runner.commands['import']!;
      expect(cmd.argParser.options, contains('branch'));
      expect(cmd.argParser.options, contains('no-history'));
    });

    test('is registered as command', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('import'));
    });
  });
}
