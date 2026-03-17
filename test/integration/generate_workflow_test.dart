import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Integration test: `fx generate` scaffolds packages that appear in
/// `fx list` and `fx graph` output.
void main() {
  group('generate workflow', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_integration_generate_',
      );
      await _initWorkspace(workspaceDir.path, 'gen_ws');
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('fx generate dart_package creates package files', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run([
        'generate',
        'dart_package',
        'my_lib',
        '--workspace',
        workspaceDir.path,
      ]);

      final pkgDir = Directory(p.join(workspaceDir.path, 'packages', 'my_lib'));
      expect(pkgDir.existsSync(), isTrue, reason: 'package directory created');

      final pubspec = File(p.join(pkgDir.path, 'pubspec.yaml'));
      expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml should exist');
      expect(pubspec.readAsStringSync(), contains('my_lib'));

      final libDir = Directory(p.join(pkgDir.path, 'lib'));
      expect(libDir.existsSync(), isTrue, reason: 'lib/ directory created');
    });

    test('fx generate --dry-run does not write files', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run([
        'generate',
        'dart_package',
        'dry_lib',
        '--dry-run',
        '--workspace',
        workspaceDir.path,
      ]);

      final pkgDir = Directory(
        p.join(workspaceDir.path, 'packages', 'dry_lib'),
      );
      expect(
        pkgDir.existsSync(),
        isFalse,
        reason: '--dry-run should not write files',
      );

      expect(output.toString(), contains('Would generate'));
    });

    test('fx generate --list shows available generators', () async {
      final output = StringBuffer();
      final runner = FxCommandRunner(outputSink: output);

      await runner.run([
        'generate',
        '--list',
        '--workspace',
        workspaceDir.path,
      ]);

      expect(output.toString(), contains('dart_package'));
      expect(output.toString(), contains('dart_cli'));
    });

    test('fx list shows generated package', () async {
      // Generate a package
      final genRunner = FxCommandRunner(outputSink: StringBuffer());
      await genRunner.run([
        'generate',
        'dart_package',
        'listed_pkg',
        '--workspace',
        workspaceDir.path,
      ]);

      // Register it in workspace members
      final rootPubspec = File(p.join(workspaceDir.path, 'pubspec.yaml'));
      final content = rootPubspec.readAsStringSync();
      rootPubspec.writeAsStringSync(
        content.replaceFirst(
          'workspace:',
          'workspace:\n  - packages/listed_pkg',
        ),
      );

      // list
      final output = StringBuffer();
      final listRunner = FxCommandRunner(outputSink: output);
      await listRunner.run(['list', '--workspace', workspaceDir.path]);

      expect(output.toString(), contains('listed_pkg'));
    });
  });
}

Future<void> _initWorkspace(String path, String name) async {
  final runner = FxCommandRunner(outputSink: StringBuffer());
  await runner.run(['init', '--name', name, '--dir', path]);
}
