import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:test/test.dart';

void main() {
  Project makeProject(String name, List<String> deps) => Project(
    name: name,
    path: '/ws/packages/$name',
    type: ProjectType.dartPackage,
    dependencies: deps,
    targets: {},
  );

  group('ProjectGraph', () {
    test('builds empty graph from empty project list', () {
      final graph = ProjectGraph.build([]);
      expect(graph.nodes, isEmpty);
    });

    test('builds graph with nodes for each project', () {
      final projects = [
        makeProject('a', []),
        makeProject('b', []),
        makeProject('c', []),
      ];
      final graph = ProjectGraph.build(projects);
      expect(graph.nodes, containsAll(['a', 'b', 'c']));
    });

    test('records dependencies correctly', () {
      final projects = [
        makeProject('a', ['b', 'c']),
        makeProject('b', []),
        makeProject('c', []),
      ];
      final graph = ProjectGraph.build(projects);
      expect(graph.dependenciesOf('a'), containsAll(['b', 'c']));
      expect(graph.dependenciesOf('b'), isEmpty);
    });

    test('records dependents (reverse graph)', () {
      final projects = [
        makeProject('app', ['core']),
        makeProject('core', []),
      ];
      final graph = ProjectGraph.build(projects);
      expect(graph.dependentsOf('core'), contains('app'));
      expect(graph.dependentsOf('app'), isEmpty);
    });

    test('transitive dependents traversal', () {
      // a depends on b, b depends on c
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['c']),
        makeProject('c', []),
      ];
      final graph = ProjectGraph.build(projects);
      // direct dependents of c = [b]
      expect(graph.dependentsOf('c'), contains('b'));
      // transitive dependents of c = [b, a]
      expect(graph.transitiveDependentsOf('c'), containsAll(['b', 'a']));
    });

    test('contains returns true for known node', () {
      final graph = ProjectGraph.build([makeProject('pkg', [])]);
      expect(graph.contains('pkg'), isTrue);
      expect(graph.contains('unknown'), isFalse);
    });

    test('handles dependency on external package not in workspace', () {
      // 'a' depends on 'ext', but 'ext' is not in the project list
      final projects = [
        makeProject('a', ['ext']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(graph.dependenciesOf('a'), contains('ext'));
      // ext should still be a node (created from the edge)
      expect(graph.contains('ext'), isTrue);
      expect(graph.dependentsOf('ext'), contains('a'));
    });

    test('diamond dependency graph (D->B,C and B->A, C->A)', () {
      final projects = [
        makeProject('d', ['b', 'c']),
        makeProject('b', ['a']),
        makeProject('c', ['a']),
        makeProject('a', []),
      ];
      final graph = ProjectGraph.build(projects);
      expect(graph.dependenciesOf('d'), containsAll(['b', 'c']));
      expect(graph.transitiveDependentsOf('a'), containsAll(['b', 'c', 'd']));
    });

    test('large graph with 10+ nodes', () {
      // Chain: p0 -> p1 -> p2 -> ... -> p9
      final projects = List.generate(
        10,
        (i) => makeProject('p$i', i < 9 ? ['p${i + 1}'] : []),
      );
      final graph = ProjectGraph.build(projects);
      expect(graph.nodes, hasLength(10));
      expect(graph.transitiveDependentsOf('p9'), hasLength(9));
      expect(graph.dependenciesOf('p0'), contains('p1'));
    });

    test('disconnected subgraphs', () {
      // Two independent clusters: a->b and x->y
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', []),
        makeProject('x', ['y']),
        makeProject('y', []),
      ];
      final graph = ProjectGraph.build(projects);
      expect(graph.dependentsOf('b'), contains('a'));
      expect(graph.dependentsOf('b'), isNot(contains('x')));
      expect(graph.transitiveDependentsOf('y'), contains('x'));
      expect(graph.transitiveDependentsOf('y'), isNot(contains('a')));
    });

    test('dependenciesOf returns empty set for unknown node', () {
      final graph = ProjectGraph.build([makeProject('a', [])]);
      expect(graph.dependenciesOf('nonexistent'), isEmpty);
    });

    test('multiple projects depending on same leaf', () {
      final projects = [
        makeProject('app1', ['core']),
        makeProject('app2', ['core']),
        makeProject('app3', ['core']),
        makeProject('core', []),
      ];
      final graph = ProjectGraph.build(projects);
      expect(graph.dependentsOf('core'), containsAll(['app1', 'app2', 'app3']));
    });
  });

  group('ProjectGraph.buildWithImplicit', () {
    test('adds implicit edges from import analysis', () {
      final projects = [
        makeProject('app', ['core']),
        makeProject('core', []),
        makeProject('utils', []),
      ];

      final graph = ProjectGraph.buildWithImplicit(projects, {
        'app': ['utils'],
      });

      expect(graph.dependenciesOf('app'), containsAll(['core', 'utils']));
      expect(graph.dependentsOf('utils'), contains('app'));
    });

    test('marks implicit edges correctly', () {
      final projects = [
        makeProject('app', ['core']),
        makeProject('core', []),
        makeProject('utils', []),
      ];

      final graph = ProjectGraph.buildWithImplicit(projects, {
        'app': ['utils'],
      });

      expect(graph.isImplicit('app', 'utils'), isTrue);
      expect(graph.isImplicit('app', 'core'), isFalse);
    });

    test('does not duplicate already declared edges', () {
      final projects = [
        makeProject('app', ['core']),
        makeProject('core', []),
      ];

      final graph = ProjectGraph.buildWithImplicit(projects, {
        'app': ['core'], // already declared
      });

      expect(graph.dependenciesOf('app'), {'core'});
      expect(graph.isImplicit('app', 'core'), isFalse);
    });

    test('implicitEdges getter returns correct map', () {
      final projects = [
        makeProject('app', []),
        makeProject('core', []),
        makeProject('utils', []),
      ];

      final graph = ProjectGraph.buildWithImplicit(projects, {
        'app': ['core', 'utils'],
      });

      final implicit = graph.implicitEdges;
      expect(implicit['app'], containsAll(['core', 'utils']));
    });

    test('no implicit deps produces standard graph', () {
      final projects = [
        makeProject('app', ['core']),
        makeProject('core', []),
      ];

      final graph = ProjectGraph.buildWithImplicit(projects, {});

      expect(graph.dependenciesOf('app'), {'core'});
      expect(graph.implicitEdges, isEmpty);
    });

    test('ignores implicit deps for unknown projects', () {
      final projects = [makeProject('app', [])];

      final graph = ProjectGraph.buildWithImplicit(projects, {
        'app': ['nonexistent'],
      });

      expect(graph.dependenciesOf('app'), isEmpty);
      expect(graph.implicitEdges, isEmpty);
    });
  });

  group('ProjectGraph.buildWithPlugins', () {
    test('with no hooks behaves like build()', () async {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', []),
      ];
      final graph = await ProjectGraph.buildWithPlugins(projects, hooks: []);
      expect(graph.dependenciesOf('a'), contains('b'));
      expect(graph.dependenciesOf('b'), isEmpty);
    });

    test('plugin-contributed edges appear in the graph', () async {
      final projects = [makeProject('x', []), makeProject('y', [])];
      final hook = _TestDepHook({
        'x': ['y'],
      });

      final graph = await ProjectGraph.buildWithPlugins(
        projects,
        hooks: [hook],
      );
      expect(graph.dependenciesOf('x'), contains('y'));
    });

    test(
      'plugin edges do not create duplicates with pubspec.yaml edges',
      () async {
        final projects = [
          makeProject('a', ['b']),
          makeProject('b', []),
        ];
        final hook = _TestDepHook({
          'a': ['b'],
        }); // same edge already in pubspec

        final graph = await ProjectGraph.buildWithPlugins(
          projects,
          hooks: [hook],
        );
        // Should have exactly one edge a->b
        expect(graph.dependenciesOf('a').length, 1);
      },
    );

    test('multiple hooks contribute edges independently', () async {
      final projects = [
        makeProject('a', []),
        makeProject('b', []),
        makeProject('c', []),
      ];
      final hook1 = _TestDepHook({
        'a': ['b'],
      });
      final hook2 = _TestDepHook({
        'a': ['c'],
      });

      final graph = await ProjectGraph.buildWithPlugins(
        projects,
        hooks: [hook1, hook2],
      );
      expect(graph.dependenciesOf('a'), containsAll(['b', 'c']));
    });
  });
}

class _TestDepHook implements PluginHook {
  final Map<String, List<String>> deps;
  _TestDepHook(this.deps);

  @override
  String get name => 'test-dep-hook';

  @override
  String get fileGlob => '**/*.custom';

  @override
  Future<List<Project>> inferProjects(
    String workspaceRoot,
    List<String> matchedFiles,
  ) async => [];

  @override
  Future<Map<String, List<String>>> inferDependencies(
    List<Project> projects,
  ) async => deps;

  @override
  Future<InferredCacheConfig?> inferCacheConfig(
    Project project,
    Target target,
  ) async => null;

  @override
  Future<bool> preTasksExecution(TaskRunMetadata metadata) async => true;

  @override
  Future<void> postTasksExecution(
    TaskRunMetadata metadata,
    List<Map<String, dynamic>> results,
  ) async {}

  @override
  Future<Map<String, dynamic>> createMetadata(TaskRunMetadata metadata) async =>
      {};
}
