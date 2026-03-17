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

  group('CycleDetector', () {
    test('no cycle in acyclic graph', () {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['c']),
        makeProject('c', []),
      ];
      final graph = ProjectGraph.build(projects);
      expect(CycleDetector.hasCycle(graph), isFalse);
      expect(CycleDetector.findCycles(graph), isEmpty);
    });

    test('detects simple cycle A->B->A', () {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['a']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(CycleDetector.hasCycle(graph), isTrue);
      final cycles = CycleDetector.findCycles(graph);
      expect(cycles, isNotEmpty);
    });

    test('detects self-loop', () {
      final projects = [
        makeProject('a', ['a']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(CycleDetector.hasCycle(graph), isTrue);
    });

    test('detects cycle in longer chain A->B->C->A', () {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['c']),
        makeProject('c', ['a']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(CycleDetector.hasCycle(graph), isTrue);
      final cycles = CycleDetector.findCycles(graph);
      // Cycle should contain all three nodes
      final allNodes = cycles.expand((c) => c).toSet();
      expect(allNodes, containsAll(['a', 'b', 'c']));
    });

    test('no false positive for disconnected graph', () {
      final projects = [
        makeProject('a', []),
        makeProject('b', []),
        makeProject('c', ['b']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(CycleDetector.hasCycle(graph), isFalse);
    });

    test('detects multiple independent cycles', () {
      // Two independent cycles: a->b->a and x->y->x
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['a']),
        makeProject('x', ['y']),
        makeProject('y', ['x']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(CycleDetector.hasCycle(graph), isTrue);
      final cycles = CycleDetector.findCycles(graph);
      expect(cycles.length, greaterThanOrEqualTo(2));
    });

    test('cycle in subgraph while other parts are acyclic', () {
      final projects = [
        makeProject('clean1', ['clean2']),
        makeProject('clean2', []),
        makeProject('x', ['y']),
        makeProject('y', ['x']),
      ];
      final graph = ProjectGraph.build(projects);
      expect(CycleDetector.hasCycle(graph), isTrue);
      final cycles = CycleDetector.findCycles(graph);
      final allCycleNodes = cycles.expand((c) => c).toSet();
      expect(allCycleNodes, containsAll(['x', 'y']));
      expect(allCycleNodes, isNot(contains('clean1')));
    });

    test('no cycle in empty graph', () {
      final graph = ProjectGraph.build([]);
      expect(CycleDetector.hasCycle(graph), isFalse);
      expect(CycleDetector.findCycles(graph), isEmpty);
    });

    test('no cycle in single node without self-loop', () {
      final graph = ProjectGraph.build([makeProject('solo', [])]);
      expect(CycleDetector.hasCycle(graph), isFalse);
    });

    test('findCycles returns correct cycle path nodes', () {
      final projects = [
        makeProject('a', ['b']),
        makeProject('b', ['c']),
        makeProject('c', ['a']),
      ];
      final graph = ProjectGraph.build(projects);
      final cycles = CycleDetector.findCycles(graph);
      expect(cycles, hasLength(1));
      expect(cycles.first, containsAll(['a', 'b', 'c']));
    });
  });
}
