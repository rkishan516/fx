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

  group('TopologicalSort', () {
    test('returns single node in isolation', () {
      final projects = [makeProject('a', [])];
      final graph = ProjectGraph.build(projects);
      final sorted = TopologicalSort.sort(projects, graph);
      expect(sorted, hasLength(1));
      expect(sorted.first.name, 'a');
    });

    test('returns leaf before dependent (A depends on B => [B, A])', () {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', []),
      ];
      final graph = ProjectGraph.build(projects);
      final sorted = TopologicalSort.sort(projects, graph);
      final names = sorted.map((p) => p.name).toList();
      expect(names.indexOf('b'), lessThan(names.indexOf('a')));
    });

    test('handles chain A->B->C correctly: [C, B, A]', () {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['c']),
        makeProject('c', []),
      ];
      final graph = ProjectGraph.build(projects);
      final sorted = TopologicalSort.sort(projects, graph);
      final names = sorted.map((p) => p.name).toList();
      expect(names.indexOf('c'), lessThan(names.indexOf('b')));
      expect(names.indexOf('b'), lessThan(names.indexOf('a')));
    });

    test('handles diamond dependency: D->B,C and B->A,C->A', () {
      final projects = [
        makeProject('d', ['b', 'c']),
        makeProject('b', ['a']),
        makeProject('c', ['a']),
        makeProject('a', []),
      ];
      final graph = ProjectGraph.build(projects);
      final sorted = TopologicalSort.sort(projects, graph);
      final names = sorted.map((p) => p.name).toList();
      // 'a' must come before 'b', 'c', 'd'
      expect(names.indexOf('a'), lessThan(names.indexOf('b')));
      expect(names.indexOf('a'), lessThan(names.indexOf('c')));
    });

    test('independent projects in any order', () {
      final projects = [
        makeProject('x', []),
        makeProject('y', []),
        makeProject('z', []),
      ];
      final graph = ProjectGraph.build(projects);
      final sorted = TopologicalSort.sort(projects, graph);
      // All 3 present, any order is valid
      expect(sorted.map((p) => p.name).toSet(), containsAll(['x', 'y', 'z']));
    });

    test('empty project list returns empty list', () {
      final graph = ProjectGraph.build([]);
      final sorted = TopologicalSort.sort([], graph);
      expect(sorted, isEmpty);
    });

    test('subset sort only includes requested projects', () {
      final all = [
        makeProject('a', ['b']),
        makeProject('b', ['c']),
        makeProject('c', []),
        makeProject('unrelated', []),
      ];
      final graph = ProjectGraph.build(all);

      // Sort only a subset
      final subset = [all[0], all[1]]; // a and b only
      final sorted = TopologicalSort.sort(subset, graph);
      expect(sorted, hasLength(2));
      final names = sorted.map((p) => p.name).toList();
      expect(names.indexOf('b'), lessThan(names.indexOf('a')));
    });

    test('large graph (10 nodes chain) produces correct order', () {
      // p0 -> p1 -> p2 -> ... -> p9
      final projects = List.generate(
        10,
        (i) => makeProject('p$i', i < 9 ? ['p${i + 1}'] : []),
      );
      final graph = ProjectGraph.build(projects);
      final sorted = TopologicalSort.sort(projects, graph);
      final names = sorted.map((p) => p.name).toList();
      // p9 should be first (leaf), p0 should be last
      expect(names.first, 'p9');
      expect(names.last, 'p0');
    });

    test('throws StateError on cyclic dependencies', () {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['a']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(
        () => TopologicalSort.sort(projects, graph),
        throwsA(isA<StateError>()),
      );
    });

    test('deterministic output for same input', () {
      final projects = [
        makeProject('c', []),
        makeProject('b', []),
        makeProject('a', []),
      ];
      final graph = ProjectGraph.build(projects);
      final sorted1 = TopologicalSort.sort(projects, graph);
      final sorted2 = TopologicalSort.sort(projects, graph);
      expect(
        sorted1.map((p) => p.name).toList(),
        equals(sorted2.map((p) => p.name).toList()),
      );
    });
  });
}
