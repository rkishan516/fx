import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MigrateCommand', () {
    late Directory tempDir;
    late StringBuffer output;
    late FxCommandRunner runner;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_migrate_');
      output = StringBuffer();
      runner = FxCommandRunner(outputSink: output);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('parses melos.yaml and generates fx config', () async {
      // Create a melos workspace
      File(p.join(tempDir.path, 'melos.yaml')).writeAsStringSync('''
name: my_workspace

packages:
  - packages/**

scripts:
  analyze:
    run: dart analyze .
    exec:
      concurrency: 5
  test:
    run: dart test
  format:
    run: dart format .
  custom_lint:
    run: dart run custom_lints
''');

      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1
''');

      try {
        await runner.run(['migrate', '--dir', tempDir.path]);
      } catch (_) {
        // ProcessExit
      }

      final pubspecContent = File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).readAsStringSync();
      expect(pubspecContent, contains('fx:'));
      expect(pubspecContent, contains('packages:'));
      expect(output.toString(), contains('Migration'));
    });

    test('detects melos.yaml absence and reports error', () async {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1
''');

      try {
        await runner.run(['migrate', '--dir', tempDir.path]);
        fail('Should have thrown');
      } catch (e) {
        expect(e.toString(), contains('melos.yaml'));
      }
    });

    test('MelosConfig parses packages patterns', () {
      final config = MelosConfig.parse('''
name: my_workspace

packages:
  - packages/**
  - apps/*
''');

      expect(config.name, 'my_workspace');
      expect(config.packages, ['packages/**', 'apps/*']);
    });

    test('MelosConfig parses scripts', () {
      final config = MelosConfig.parse('''
name: my_workspace

packages:
  - packages/**

scripts:
  test:
    run: dart test
  build:
    run: dart run build_runner build
''');

      expect(config.scripts, hasLength(2));
      expect(config.scripts['test'], 'dart test');
      expect(config.scripts['build'], 'dart run build_runner build');
    });

    test('MelosConfig handles string-only script values', () {
      final config = MelosConfig.parse('''
name: my_workspace

packages:
  - packages/**

scripts:
  test: dart test
  build: dart compile
''');

      expect(config.scripts['test'], 'dart test');
      expect(config.scripts['build'], 'dart compile');
    });

    test('--update-deps updates dependency across packages', () async {
      // Create a workspace with fx.yaml and two packages
      File(p.join(tempDir.path, 'fx.yaml')).writeAsStringSync('''
packages:
  - packages/*
''');
      for (final name in ['pkg_a', 'pkg_b']) {
        final dir = Directory(p.join(tempDir.path, 'packages', name))
          ..createSync(recursive: true);
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: $name
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
dependencies:
  http: ^0.13.0
''');
      }

      // Change to temp dir for workspace discovery
      final oldDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run(['migrate', '--update-deps', 'http:^1.2.0']);
      } catch (_) {
        // ProcessExit
      } finally {
        Directory.current = oldDir;
      }

      final pkgA = File(
        p.join(tempDir.path, 'packages', 'pkg_a', 'pubspec.yaml'),
      ).readAsStringSync();
      final pkgB = File(
        p.join(tempDir.path, 'packages', 'pkg_b', 'pubspec.yaml'),
      ).readAsStringSync();

      expect(pkgA, contains('1.2.0'));
      expect(pkgB, contains('1.2.0'));
      expect(output.toString(), contains('Updated http'));
    });

    group('plugin migrations', () {
      late Directory tempDir2;
      late StringBuffer output2;
      late MigrationRegistry registry;

      setUp(() async {
        tempDir2 = await Directory.systemTemp.createTemp('fx_migrate_plugin_');
        output2 = StringBuffer();
        registry = MigrationRegistry();
      });

      tearDown(() async {
        await tempDir2.delete(recursive: true);
      });

      test('--list shows all registered migrations', () async {
        registry.register(
          _FakeMigration(
            plugin: 'my_plugin',
            from: '1.0.0',
            to: '2.0.0',
            description: 'Upgrade config format',
          ),
        );
        registry.register(
          _FakeMigration(
            plugin: 'other_plugin',
            from: '0.5.0',
            to: '1.0.0',
            description: 'Add targets section',
          ),
        );

        final runner2 = FxCommandRunner(
          outputSink: output2,
          migrationRegistry: registry,
        );
        try {
          await runner2.run(['migrate', '--list']);
        } catch (_) {}

        final out = output2.toString();
        expect(out, contains('my_plugin'));
        expect(out, contains('1.0.0'));
        expect(out, contains('2.0.0'));
        expect(out, contains('other_plugin'));
      });

      test('--list with --plugin filters by plugin name', () async {
        registry.register(
          _FakeMigration(
            plugin: 'my_plugin',
            from: '1.0.0',
            to: '2.0.0',
            description: 'Upgrade config format',
          ),
        );
        registry.register(
          _FakeMigration(
            plugin: 'other_plugin',
            from: '0.5.0',
            to: '1.0.0',
            description: 'Add targets section',
          ),
        );

        final runner2 = FxCommandRunner(
          outputSink: output2,
          migrationRegistry: registry,
        );
        try {
          await runner2.run(['migrate', '--list', '--plugin', 'my_plugin']);
        } catch (_) {}

        final out = output2.toString();
        expect(out, contains('my_plugin'));
        expect(out, isNot(contains('other_plugin')));
      });

      test('--plugin runs migrations between versions', () async {
        final applied = <String>[];
        registry.register(
          _FakeMigration(
            plugin: 'my_plugin',
            from: '1.0.0',
            to: '2.0.0',
            description: 'Upgrade config format',
            onExecute: (root, changes) => applied.add('1->2'),
          ),
        );

        File(
          p.join(tempDir2.path, 'fx.yaml'),
        ).writeAsStringSync('packages:\n  - packages/*\n');

        final runner2 = FxCommandRunner(
          outputSink: output2,
          migrationRegistry: registry,
        );
        final oldDir = Directory.current;
        Directory.current = tempDir2;
        try {
          await runner2.run([
            'migrate',
            '--plugin',
            'my_plugin',
            '--from',
            '1.0.0',
            '--to',
            '2.0.0',
          ]);
        } catch (_) {
        } finally {
          Directory.current = oldDir;
        }

        expect(applied, contains('1->2'));
        expect(output2.toString(), contains('my_plugin'));
      });

      test('--plugin with --dry-run shows changes without applying', () async {
        final applied = <String>[];
        registry.register(
          _FakeMigration(
            plugin: 'my_plugin',
            from: '1.0.0',
            to: '2.0.0',
            description: 'Upgrade config format',
            changes: [
              MigrationChange(
                type: MigrationChangeType.modify,
                filePath: 'fx.yaml',
                description: 'Update format',
                before: 'old content',
                after: 'new content',
              ),
            ],
            onExecute: (root, changes) => applied.add('executed'),
          ),
        );

        File(
          p.join(tempDir2.path, 'fx.yaml'),
        ).writeAsStringSync('packages:\n  - packages/*\n');

        final runner2 = FxCommandRunner(
          outputSink: output2,
          migrationRegistry: registry,
        );
        final oldDir = Directory.current;
        Directory.current = tempDir2;
        try {
          await runner2.run([
            'migrate',
            '--plugin',
            'my_plugin',
            '--from',
            '1.0.0',
            '--to',
            '2.0.0',
            '--dry-run',
          ]);
        } catch (_) {
        } finally {
          Directory.current = oldDir;
        }

        expect(applied, isEmpty);
        expect(output2.toString(), contains('fx.yaml'));
      });
    });

    test('--update-deps with --dry-run does not modify files', () async {
      File(p.join(tempDir.path, 'fx.yaml')).writeAsStringSync('''
packages:
  - packages/*
''');
      final dir = Directory(p.join(tempDir.path, 'packages', 'pkg_a'))
        ..createSync(recursive: true);
      final pubspecContent = '''
name: pkg_a
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
dependencies:
  http: ^0.13.0
''';
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(pubspecContent);

      final oldDir = Directory.current;
      Directory.current = tempDir;
      try {
        await runner.run([
          'migrate',
          '--update-deps',
          'http:^1.2.0',
          '--dry-run',
        ]);
      } catch (_) {
        // ProcessExit
      } finally {
        Directory.current = oldDir;
      }

      // File should not be changed
      final content = File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync();
      expect(content, contains('^0.13.0'));
      expect(output.toString(), contains('Would update'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _FakeMigration extends MigrationGenerator {
  @override
  final String pluginName;
  @override
  final String fromVersion;
  @override
  final String toVersion;

  final String description;
  final List<MigrationChange> changes;
  final void Function(String root, List<MigrationChange> changes)? onExecute;

  _FakeMigration({
    required String plugin,
    required String from,
    required String to,
    required this.description,
    List<MigrationChange>? changes,
    this.onExecute,
  }) : pluginName = plugin,
       fromVersion = from,
       toVersion = to,
       changes = changes ?? [];

  @override
  Future<List<MigrationChange>> prepare(String workspaceRoot) async => changes;

  @override
  Future<void> execute(
    String workspaceRoot,
    List<MigrationChange> changes,
  ) async {
    onExecute?.call(workspaceRoot, changes);
  }
}
