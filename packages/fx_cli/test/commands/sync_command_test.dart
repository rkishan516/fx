import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SyncCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_sync_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('reports in-sync workspace', () async {
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

      // Create pubspec.lock so that check passes
      File(p.join(tempDir.path, 'pubspec.lock')).writeAsStringSync('');

      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['sync']);
      } finally {
        Directory.current = prevDir;
      }

      expect(output.toString(), contains('in sync'));
    });

    test('detects missing resolution workspace', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run(['init', '--name', 'test_ws', '--dir', tempDir.path]);

      // Create a package WITHOUT resolution: workspace
      final pkgDir = p.join(tempDir.path, 'packages', 'bad');
      Directory(p.join(pkgDir, 'lib')).createSync(recursive: true);
      File(p.join(pkgDir, 'pubspec.yaml')).writeAsStringSync('''
name: bad
version: 0.1.0
environment:
  sdk: ^3.11.1
''');

      // Create pubspec.lock
      File(p.join(tempDir.path, 'pubspec.lock')).writeAsStringSync('');

      output.clear();

      final prevDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['sync']);
      } finally {
        Directory.current = prevDir;
      }

      expect(output.toString(), contains('OUT OF SYNC'));
    });

    test('is registered as command', () {
      final runner = FxCommandRunner(outputSink: StringBuffer());
      expect(runner.commands, contains('sync'));
    });
  });
}
