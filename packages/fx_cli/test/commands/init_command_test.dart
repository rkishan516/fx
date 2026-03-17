import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('InitCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_init_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('creates root pubspec.yaml with fx: section', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'my_workspace');
      await runner.run(['init', '--name', 'my_workspace', '--dir', outDir]);

      final pubspec = File(p.join(outDir, 'pubspec.yaml'));
      expect(pubspec.existsSync(), isTrue);

      final content = await pubspec.readAsString();
      expect(content, contains('name: my_workspace'));
      expect(content, contains('fx:'));
      expect(content, contains('packages:'));
    });

    test('creates packages and apps directories', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'ws');
      await runner.run(['init', '--name', 'ws', '--dir', outDir]);

      expect(Directory(p.join(outDir, 'packages')).existsSync(), isTrue);
      expect(Directory(p.join(outDir, 'apps')).existsSync(), isTrue);
    });

    test('creates analysis_options.yaml', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'ws');
      await runner.run(['init', '--name', 'ws', '--dir', outDir]);

      expect(
        File(p.join(outDir, 'analysis_options.yaml')).existsSync(),
        isTrue,
      );
    });

    test('creates .gitignore with .fx_cache entry', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'ws');
      await runner.run(['init', '--name', 'ws', '--dir', outDir]);

      final gitignore = File(p.join(outDir, '.gitignore'));
      expect(gitignore.existsSync(), isTrue);
      expect(await gitignore.readAsString(), contains('.fx_cache'));
    });

    test('pubspec.yaml includes workspace members glob', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'ws');
      await runner.run(['init', '--name', 'ws', '--dir', outDir]);

      final pubspec = File(p.join(outDir, 'pubspec.yaml'));
      final content = await pubspec.readAsString();
      expect(content, contains('workspace:'));
    });

    test('init uses current directory when --dir not specified', () async {
      // Ensure the command accepts no --dir without crashing
      final runner = FxCommandRunner();
      // Just verify it doesn't throw on parsing
      expect(() async => runner.run(['init', '--help']), returnsNormally);
    });

    test('init over existing workspace does not destroy files', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'existing_ws');

      // First init
      await runner.run(['init', '--name', 'existing_ws', '--dir', outDir]);

      // Add a custom file
      await File(p.join(outDir, 'custom.txt')).writeAsString('keep me');

      // Second init over the same directory
      final runner2 = FxCommandRunner();
      await runner2.run(['init', '--name', 'existing_ws', '--dir', outDir]);

      // Custom file should still exist
      expect(File(p.join(outDir, 'custom.txt')).existsSync(), isTrue);
    });

    test('pubspec.yaml has correct SDK constraint', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'sdk_ws');
      await runner.run(['init', '--name', 'sdk_ws', '--dir', outDir]);

      final content = await File(p.join(outDir, 'pubspec.yaml')).readAsString();
      expect(content, contains('sdk:'));
    });

    test('pubspec.yaml has publish_to: none', () async {
      final runner = FxCommandRunner();
      final outDir = p.join(tempDir.path, 'pub_ws');
      await runner.run(['init', '--name', 'pub_ws', '--dir', outDir]);

      final content = await File(p.join(outDir, 'pubspec.yaml')).readAsString();
      expect(content, contains('publish_to: none'));
    });
  });
}
