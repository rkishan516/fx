/// End-to-end integration tests covering all new Nx-parity features.
///
/// These tests exercise full pipelines through real temp workspaces,
/// verifying that features compose correctly together.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Integration: full pipeline', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_integration_');
      await _createFullWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    // -------------------------------------------------------------------------
    // Task graph visualization
    // -------------------------------------------------------------------------

    test(
      'fx graph --tasks --format json outputs task graph with dependsOn',
      () async {
        final buf = StringBuffer();
        final runner = FxCommandRunner(outputSink: buf);
        await runner.run([
          'graph',
          '--tasks',
          '--format',
          'json',
          '--workspace',
          workspaceDir.path,
        ]);

        final json = jsonDecode(buf.toString()) as Map;
        expect(json.containsKey('nodes'), isTrue);
        expect(json.containsKey('edges'), isTrue);
        final nodes = json['nodes'] as List;
        expect(nodes.isNotEmpty, isTrue);
        // Should have test and build nodes for both packages
        final ids = nodes.map((n) => (n as Map)['id'] as String).toSet();
        expect(ids, contains('pkg_a:build'));
        expect(ids, contains('pkg_b:build'));
      },
    );

    test('fx graph --tasks --format dot outputs valid DOT', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      await runner.run([
        'graph',
        '--tasks',
        '--format',
        'dot',
        '--workspace',
        workspaceDir.path,
      ]);

      final dot = buf.toString();
      expect(dot, startsWith('digraph'));
      expect(dot, contains('pkg_a__build'));
    });

    // -------------------------------------------------------------------------
    // CI info
    // -------------------------------------------------------------------------

    test('fx ci-info outputs valid JSON', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      await runner.run(['ci-info']);

      final json = jsonDecode(buf.toString()) as Map;
      expect(
        json.keys,
        containsAll(['provider', 'baseRef', 'cachePaths', 'concurrency']),
      );
      expect(json['concurrency'], isA<int>());
    });

    test('fx ci-info --provider github shows github provider', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      await runner.run(['ci-info', '--provider', 'github']);

      final json = jsonDecode(buf.toString()) as Map;
      expect(json['provider'], 'github');
    });

    // -------------------------------------------------------------------------
    // Migration framework
    // -------------------------------------------------------------------------

    test(
      'fx migrate --list shows empty message when no migrations registered',
      () async {
        final buf = StringBuffer();
        final registry = MigrationRegistry();
        final runner = FxCommandRunner(
          outputSink: buf,
          migrationRegistry: registry,
        );
        try {
          await runner.run(['migrate', '--list']);
        } catch (_) {}

        expect(buf.toString(), contains('No migrations registered.'));
      },
    );

    test('fx migrate --list shows migrations in registry', () async {
      final buf = StringBuffer();
      final registry = MigrationRegistry();
      registry.register(
        _FakeIntegrationMigration(
          plugin: 'integration_plugin',
          from: '1.0.0',
          to: '2.0.0',
        ),
      );

      final runner = FxCommandRunner(
        outputSink: buf,
        migrationRegistry: registry,
      );
      try {
        await runner.run(['migrate', '--list']);
      } catch (_) {}

      final out = buf.toString();
      expect(out, contains('integration_plugin'));
      expect(out, contains('1.0.0'));
      expect(out, contains('2.0.0'));
    });

    // -------------------------------------------------------------------------
    // Plugin capabilities
    // -------------------------------------------------------------------------

    test('fx plugin list shows hook plugins with capabilities', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      await runner.run(['plugin', 'list', '--workspace', workspaceDir.path]);

      final out = buf.toString();
      expect(out, contains('Built-in generators'));
      // Workspace has a plugin configured
      expect(out, contains('inference_plugin'));
      expect(out, contains('inference'));
    });

    // -------------------------------------------------------------------------
    // Regression: existing commands still work
    // -------------------------------------------------------------------------

    test('fx graph text output still works (regression)', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      await runner.run(['graph', '--workspace', workspaceDir.path]);

      final out = buf.toString();
      expect(out, contains('pkg_a'));
      expect(out, contains('pkg_b'));
    });

    test('fx migrate --version-update still works (regression)', () async {
      final buf = StringBuffer();
      final runner = FxCommandRunner(outputSink: buf);
      final oldDir = Directory.current;
      Directory.current = workspaceDir;
      try {
        await runner.run(['migrate', '--version-update']);
      } catch (_) {
      } finally {
        Directory.current = oldDir;
      }
      // Should not crash — output can be "already up to date" or applied
      expect(buf.toString().isNotEmpty, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Future<void> _createFullWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: integration_ws
publish_to: none
environment:
  sdk: ^3.11.1
workspace:
  - packages/pkg_a
  - packages/pkg_b
fx:
  packages:
    - packages/*
  targets:
    build:
      executor: dart compile
    test:
      executor: dart test
      dependsOn:
        - ^build
  plugins:
    - plugin: inference_plugin
      capabilities:
        - inference
''');

  // pkg_a: no deps
  final pkgADir = Directory(p.join(root, 'packages', 'pkg_a'));
  await pkgADir.create(recursive: true);
  await File(p.join(pkgADir.path, 'pubspec.yaml')).writeAsString('''
name: pkg_a
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');

  // pkg_b: depends on pkg_a
  final pkgBDir = Directory(p.join(root, 'packages', 'pkg_b'));
  await pkgBDir.create(recursive: true);
  await File(p.join(pkgBDir.path, 'pubspec.yaml')).writeAsString('''
name: pkg_b
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
dependencies:
  pkg_a:
    path: ../pkg_a
''');
}

class _FakeIntegrationMigration extends MigrationGenerator {
  @override
  final String pluginName;
  @override
  final String fromVersion;
  @override
  final String toVersion;

  _FakeIntegrationMigration({
    required String plugin,
    required String from,
    required String to,
  }) : pluginName = plugin,
       fromVersion = from,
       toVersion = to;

  @override
  Future<List<MigrationChange>> prepare(String workspaceRoot) async => [];

  @override
  Future<void> execute(
    String workspaceRoot,
    List<MigrationChange> changes,
  ) async {}
}
