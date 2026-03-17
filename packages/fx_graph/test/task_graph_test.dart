import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:test/test.dart';

void main() {
  // Helper to build a minimal Project.
  Project makeProject(
    String name, {
    List<String> deps = const [],
    Map<String, Target> targets = const {},
  }) => Project(
    name: name,
    path: '/ws/packages/$name',
    type: ProjectType.dartPackage,
    dependencies: deps,
    targets: targets,
  );

  // Helper to build a minimal Target.
  Target makeTarget(String name, {List<String> dependsOn = const []}) => Target(
    name: name,
    executor: 'dart test',
    dependsOnEntries: dependsOn.map((d) => DependsOnEntry(target: d)).toList(),
  );

  // Helper to build a minimal Workspace.
  Workspace makeWorkspace(
    List<Project> projects, {
    Map<String, Target> wsTargets = const {},
  }) {
    final config = FxConfig(
      targets: wsTargets,
      packages: const [],
      cacheConfig: const CacheConfig(enabled: false, directory: '.fx_cache'),
      generators: const [],
    );
    return Workspace(rootPath: '/ws', config: config, projects: projects);
  }

  group('TaskGraph', () {
    test('fromWorkspace creates nodes for all project:target pairs', () {
      final wsTargets = {
        'test': makeTarget('test'),
        'build': makeTarget('build'),
      };
      final projects = [makeProject('pkg_a'), makeProject('pkg_b')];
      final workspace = makeWorkspace(projects, wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      expect(graph.nodes.map((n) => n.id).toSet(), {
        'pkg_a:test',
        'pkg_a:build',
        'pkg_b:test',
        'pkg_b:build',
      });
    });

    test('fromWorkspace with no targets produces empty graph', () {
      final workspace = makeWorkspace([makeProject('pkg_a')]);
      final graph = TaskGraph.fromWorkspace(workspace);
      expect(graph.nodes, isEmpty);
    });

    test('project-level target overrides workspace target', () {
      final wsTargets = {'test': makeTarget('test')};
      final projectTarget = makeTarget('test', dependsOn: ['build']);
      final projects = [
        makeProject('pkg_a', targets: {'test': projectTarget}),
      ];
      final workspace = makeWorkspace(projects, wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      // Should have test and build nodes for pkg_a (project-level overrides)
      final testNode = graph.nodes.firstWhere((n) => n.id == 'pkg_a:test');
      expect(testNode.dependsOn, contains('pkg_a:build'));
    });

    test('dependsOn plain target creates intra-project edge', () {
      final wsTargets = {
        'test': makeTarget('test', dependsOn: ['build']),
        'build': makeTarget('build'),
      };
      final workspace = makeWorkspace([
        makeProject('pkg_a'),
      ], wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      final testNode = graph.nodes.firstWhere((n) => n.id == 'pkg_a:test');
      expect(testNode.dependsOn, contains('pkg_a:build'));
    });

    test('dependsOn ^ creates cross-project edges for dependencies', () {
      final wsTargets = {
        'build': makeTarget('build', dependsOn: ['^build']),
      };
      final projects = [
        makeProject('pkg_a', deps: ['pkg_b']),
        makeProject('pkg_b'),
      ];
      final workspace = makeWorkspace(projects, wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      final aBuild = graph.nodes.firstWhere((n) => n.id == 'pkg_a:build');
      // pkg_a:build depends on ^build → pkg_b:build (pkg_a depends on pkg_b)
      expect(aBuild.dependsOn, contains('pkg_b:build'));

      final bBuild = graph.nodes.firstWhere((n) => n.id == 'pkg_b:build');
      // pkg_b has no deps, so no cross-project edges
      expect(bBuild.dependsOn, isEmpty);
    });

    test('dependsOn project:target creates explicit edge', () {
      final wsTargets = {
        'test': makeTarget('test', dependsOn: ['pkg_b:build']),
        'build': makeTarget('build'),
      };
      final projects = [makeProject('pkg_a'), makeProject('pkg_b')];
      final workspace = makeWorkspace(projects, wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      final aTest = graph.nodes.firstWhere((n) => n.id == 'pkg_a:test');
      expect(aTest.dependsOn, contains('pkg_b:build'));
    });

    test('toJson produces correct structure', () {
      final wsTargets = {'test': makeTarget('test')};
      final workspace = makeWorkspace([
        makeProject('pkg_a'),
      ], wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      final json = graph.toJson();
      expect(json.keys, containsAll(['nodes', 'edges']));
      expect(json['nodes'], isList);
      final nodes = json['nodes'] as List;
      expect(nodes, isNotEmpty);
      final node = nodes.first as Map<String, dynamic>;
      expect(
        node.keys,
        containsAll(['id', 'projectName', 'targetName', 'dependsOn']),
      );
    });

    test('toDot produces valid DOT syntax', () {
      final wsTargets = {
        'test': makeTarget('test', dependsOn: ['^build']),
        'build': makeTarget('build'),
      };
      final projects = [
        makeProject('pkg_a', deps: ['pkg_b']),
        makeProject('pkg_b'),
      ];
      final workspace = makeWorkspace(projects, wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      final dot = graph.toDot();
      expect(dot, startsWith('digraph'));
      expect(dot, contains('->'));
      expect(dot, contains('pkg_a__build'));
      expect(dot, contains('pkg_b__build'));
    });

    test('nodes with no dependsOn have empty dependsOn list', () {
      final wsTargets = {'build': makeTarget('build')};
      final workspace = makeWorkspace([
        makeProject('pkg_a'),
      ], wsTargets: wsTargets);
      final graph = TaskGraph.fromWorkspace(workspace);

      final build = graph.nodes.firstWhere((n) => n.id == 'pkg_a:build');
      expect(build.dependsOn, isEmpty);
    });
  });
}
