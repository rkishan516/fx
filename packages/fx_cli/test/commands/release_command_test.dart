import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ReleaseCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_release_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('version bumps patch by default', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      // Create a package
      final pkgDir = p.join(tempDir.path, 'packages', 'core');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: core
version: 1.0.0
resolution: workspace
environment:
  sdk: ^3.11.1
''');

      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run([
          'release',
          'version',
          '--dry-run',
          '--workspace',
          tempDir.path,
        ]);
      } finally {
        Directory.current = prevDir;
      }

      expect(output.toString(), contains('1.0.0 -> 1.0.1'));
    });

    test('changelog dry-run outputs formatted entries', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      // Need git repo for changelog
      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await Process.run('git', ['init'], workingDirectory: tempDir.path);
        await Process.run('git', ['add', '.'], workingDirectory: tempDir.path);
        await Process.run('git', [
          'commit',
          '-m',
          'feat: initial commit',
        ], workingDirectory: tempDir.path);
        await Process.run('git', [
          'commit',
          '--allow-empty',
          '-m',
          'fix(core): resolve bug',
        ], workingDirectory: tempDir.path);

        output.clear();
        await runner.run([
          'release',
          'changelog',
          '--dry-run',
          '--workspace',
          tempDir.path,
        ]);
      } finally {
        Directory.current = prevDir;
      }

      final out = output.toString();
      expect(out, contains('Features'));
      expect(out, contains('Bug Fixes'));
      expect(out, contains('**core:**'));
    });

    test('is registered as command', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('release'));
    });

    test('has --from and --to flags', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      final cmd = runner.commands['release']!;
      expect(cmd.argParser.options, contains('from'));
      expect(cmd.argParser.options, contains('to'));
    });

    test('has --conventional-commits flag', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      final cmd = runner.commands['release']!;
      expect(cmd.argParser.options, contains('conventional-commits'));
    });

    test('has --create-release flag', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      final cmd = runner.commands['release']!;
      expect(cmd.argParser.options, contains('create-release'));
    });

    test('has --group flag', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      final cmd = runner.commands['release']!;
      expect(cmd.argParser.options, contains('group'));
    });

    test('version bumps major for explicit version', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      final pkgDir = p.join(tempDir.path, 'packages', 'core');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: core
version: 1.0.0
resolution: workspace
environment:
  sdk: ^3.11.1
''');

      output.clear();
      await runner.run([
        'release',
        'version',
        '--dry-run',
        '--bump',
        'major',
        '--workspace',
        tempDir.path,
      ]);

      expect(output.toString(), contains('1.0.0 -> 2.0.0'));
    });

    test('version bumps minor', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      final pkgDir = p.join(tempDir.path, 'packages', 'core');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: core
version: 1.0.0
resolution: workspace
environment:
  sdk: ^3.11.1
''');

      output.clear();
      await runner.run([
        'release',
        'version',
        '--dry-run',
        '--bump',
        'minor',
        '--workspace',
        tempDir.path,
      ]);

      expect(output.toString(), contains('1.0.0 -> 1.1.0'));
    });
  });
}
