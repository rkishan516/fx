import 'dart:convert';
import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GraphCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_graph_test_');
      await _createWorkspaceWithDeps(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('text output lists all packages', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['graph', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      expect(output, contains('pkg_a'));
      expect(output, contains('pkg_b'));
    });

    test('--format=json outputs valid JSON adjacency list', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--format',
        'json',
        '--workspace',
        workspaceDir.path,
      ]);

      final jsonData = jsonDecode(buffer.toString()) as Map;
      expect(jsonData.containsKey('nodes'), isTrue);
    });

    test('--format=dot outputs Graphviz DOT notation', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--format',
        'dot',
        '--workspace',
        workspaceDir.path,
      ]);

      final output = buffer.toString();
      expect(output, contains('digraph'));
    });

    test('shows dependency edges between projects', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--format',
        'json',
        '--workspace',
        workspaceDir.path,
      ]);

      final jsonData = jsonDecode(buffer.toString()) as Map;
      final edges = jsonData['edges'] as List?;
      expect(edges, isNotNull);
      // pkg_b depends on pkg_a, so there should be an edge
      final hasPkgBToPkgA = edges!.any((e) {
        final edge = e as Map;
        return edge['from'] == 'pkg_b' && edge['to'] == 'pkg_a';
      });
      expect(hasPkgBToPkgA, isTrue);
    });

    test('JSON nodes contains all projects', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--format',
        'json',
        '--workspace',
        workspaceDir.path,
      ]);

      final jsonData = jsonDecode(buffer.toString()) as Map;
      final nodes = (jsonData['nodes'] as List).cast<String>();
      expect(nodes, containsAll(['pkg_a', 'pkg_b']));
    });

    test('DOT format contains arrow notation', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--format',
        'dot',
        '--workspace',
        workspaceDir.path,
      ]);

      final output = buffer.toString();
      expect(output, contains('->'));
      expect(output, contains('}'));
    });

    test('--groupByFolder groups projects by parent directory', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--groupByFolder',
        '--workspace',
        workspaceDir.path,
      ]);

      final output = buffer.toString();
      expect(output, contains('packages/'));
      expect(output, contains('pkg_a'));
      expect(output, contains('pkg_b'));
    });

    test('--groupByFolder DOT output uses subgraph clusters', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--groupByFolder',
        '--format',
        'dot',
        '--workspace',
        workspaceDir.path,
      ]);

      final output = buffer.toString();
      expect(output, contains('subgraph cluster_'));
      expect(output, contains('label='));
    });

    test('--groupByFolder JSON output includes groups', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'graph',
        '--groupByFolder',
        '--format',
        'json',
        '--workspace',
        workspaceDir.path,
      ]);

      final jsonData = jsonDecode(buffer.toString()) as Map;
      expect(jsonData.containsKey('groups'), isTrue);
      final groups = jsonData['groups'] as List;
      expect(groups, isNotEmpty);
      expect(groups.first['folder'], 'packages');
    });

    test('text output shows dependency arrows', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run(['graph', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      // pkg_b depends on pkg_a, should show an arrow
      expect(output, contains('pkg_b'));
      expect(output, contains('pkg_a'));
    });

    group('--tasks flag', () {
      test('--tasks shows task execution graph as text (regression)', () async {
        final buffer = StringBuffer();
        final runner = FxCommandRunner(outputSink: buffer);
        await runner.run([
          'graph',
          '--tasks',
          '--workspace',
          workspaceDir.path,
        ]);

        final output = buffer.toString();
        // Workspace has a 'test' target defined
        expect(output, contains('test'));
      });

      test(
        '--tasks --format json outputs valid JSON with nodes and edges',
        () async {
          final buffer = StringBuffer();
          final runner = FxCommandRunner(outputSink: buffer);
          await runner.run([
            'graph',
            '--tasks',
            '--format',
            'json',
            '--workspace',
            workspaceDir.path,
          ]);

          final output = buffer.toString();
          final json = jsonDecode(output) as Map;
          expect(json.containsKey('nodes'), isTrue);
          expect(json.containsKey('edges'), isTrue);
          final nodes = json['nodes'] as List;
          expect(nodes, isNotEmpty);
          // Should have pkg_a:test and pkg_b:test
          final ids = nodes.map((n) => (n as Map)['id']).toSet();
          expect(ids, containsAll(['pkg_a:test', 'pkg_b:test']));
        },
      );

      test('--tasks --format dot outputs valid DOT format', () async {
        // Use the workspace with task deps to have actual edges in the DOT
        final workspaceDot = await Directory.systemTemp.createTemp(
          'fx_graph_dot_',
        );
        addTearDown(() => workspaceDot.delete(recursive: true));
        await _createWorkspaceWithTaskDeps(workspaceDot.path);

        final buffer = StringBuffer();
        final runner = FxCommandRunner(outputSink: buffer);
        await runner.run([
          'graph',
          '--tasks',
          '--format',
          'dot',
          '--workspace',
          workspaceDot.path,
        ]);

        final output = buffer.toString();
        expect(output, startsWith('digraph'));
        expect(output, contains('->'));
        expect(output, contains('pkg_a__build'));
      });

      test('--tasks JSON includes dependsOn metadata', () async {
        // Use a workspace with test depending on ^build
        final workspaceDir2 = await Directory.systemTemp.createTemp(
          'fx_graph_tasks_',
        );
        addTearDown(() => workspaceDir2.delete(recursive: true));
        await _createWorkspaceWithTaskDeps(workspaceDir2.path);

        final buffer = StringBuffer();
        final runner = FxCommandRunner(outputSink: buffer);
        await runner.run([
          'graph',
          '--tasks',
          '--format',
          'json',
          '--workspace',
          workspaceDir2.path,
        ]);

        final json = jsonDecode(buffer.toString()) as Map;
        final nodes = json['nodes'] as List;
        final testNode = nodes.firstWhere(
          (n) => (n as Map)['id'] == 'pkg_b:test',
          orElse: () => null,
        );
        expect(testNode, isNotNull);
        // pkg_b:test depends on ^build, pkg_b depends on pkg_a => edge to pkg_a:build
        final deps = (testNode as Map)['dependsOn'] as List;
        expect(deps, contains('pkg_a:build'));
      });
    });
  });
}

/// Creates a workspace where test dependsOn ['^build'], so pkg_b:test → pkg_a:build.
Future<void> _createWorkspaceWithTaskDeps(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: test_workspace
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
    test:
      executor: dart test
      dependsOn:
        - ^build
    build:
      executor: dart run build_runner build
''');

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

Future<void> _createWorkspaceWithDeps(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: test_workspace
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
    test:
      executor: dart test
''');

  // pkg_a has no deps
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

  // pkg_b depends on pkg_a via path dep
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
