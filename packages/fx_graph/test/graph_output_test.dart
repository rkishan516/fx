import 'dart:convert';

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

  late ProjectGraph graph;

  setUp(() {
    final projects = [
      makeProject('a', ['b']),
      makeProject('b', ['c']),
      makeProject('c', []),
    ];
    graph = ProjectGraph.build(projects);
  });

  group('GraphOutput', () {
    test('toJson produces valid JSON with adjacency list', () {
      final output = GraphOutput.toJson(graph);
      final decoded = json.decode(output) as Map<String, dynamic>;
      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded.containsKey('nodes'), isTrue);
      expect(decoded.containsKey('edges'), isTrue);
    });

    test('toDot produces valid DOT format', () {
      final output = GraphOutput.toDot(graph);
      expect(output, startsWith('digraph'));
      expect(output, contains('->'));
      expect(output, contains('"a"'));
      expect(output, contains('"b"'));
    });

    test('toText lists all nodes', () {
      final output = GraphOutput.toText(graph);
      expect(output, contains('a'));
      expect(output, contains('b'));
      expect(output, contains('c'));
    });

    test('toJson nodes contains all projects', () {
      final output = GraphOutput.toJson(graph);
      expect(output, contains('"a"'));
      expect(output, contains('"b"'));
      expect(output, contains('"c"'));
    });
  });
}
