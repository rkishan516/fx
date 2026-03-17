import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Integration test: `fx init` creates a valid workspace structure and
/// `fx list` reports projects after packages are added.
void main() {
  group('init workflow', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_integration_init_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('fx init creates workspace pubspec.yaml', () async {
      final wsDir = p.join(tempDir.path, 'my_ws');

      final runner = FxCommandRunner(outputSink: StringBuffer());
      await runner.run(['init', '--name', 'my_ws', '--dir', wsDir]);

      final pubspec = File(p.join(wsDir, 'pubspec.yaml'));
      expect(
        pubspec.existsSync(),
        isTrue,
        reason: 'pubspec.yaml should be created',
      );

      final content = pubspec.readAsStringSync();
      expect(content, contains('name: my_ws'));
      expect(content, contains('workspace:'));
      expect(content, contains('fx:'));
    });

    test('fx init creates packages/ directory', () async {
      final wsDir = p.join(tempDir.path, 'ws2');

      final runner = FxCommandRunner(outputSink: StringBuffer());
      await runner.run(['init', '--name', 'ws2', '--dir', wsDir]);

      expect(Directory(p.join(wsDir, 'packages')).existsSync(), isTrue);
    });

    test('fx list shows no projects in empty workspace', () async {
      final wsDir = p.join(tempDir.path, 'empty_ws');

      final runner = FxCommandRunner(outputSink: StringBuffer());
      await runner.run(['init', '--name', 'empty_ws', '--dir', wsDir]);

      final output = StringBuffer();
      final listRunner = FxCommandRunner(outputSink: output);
      await listRunner.run(['list', '--workspace', wsDir]);

      // With no packages glob match, list is empty or shows header
      expect(output.toString(), isNotEmpty);
    });

    test('fx list shows project after it is manually added', () async {
      final wsDir = p.join(tempDir.path, 'ws3');

      final initRunner = FxCommandRunner(outputSink: StringBuffer());
      await initRunner.run(['init', '--name', 'ws3', '--dir', wsDir]);

      // Manually create a minimal package in packages/
      final pkgDir = Directory(p.join(wsDir, 'packages', 'alpha'));
      await pkgDir.create(recursive: true);
      await File(p.join(pkgDir.path, 'pubspec.yaml')).writeAsString('''
name: alpha
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');

      // Update root pubspec.yaml workspace list
      final rootPubspec = File(p.join(wsDir, 'pubspec.yaml'));
      final src = rootPubspec.readAsStringSync();
      rootPubspec.writeAsStringSync(
        src.replaceFirst('workspace:', 'workspace:\n  - packages/alpha'),
      );

      final output = StringBuffer();
      final listRunner = FxCommandRunner(outputSink: output);
      await listRunner.run(['list', '--workspace', wsDir]);

      expect(output.toString(), contains('alpha'));
    });
  });
}
