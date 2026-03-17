import 'dart:convert';

import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:test/test.dart';

// Import the formatter — it's exported via fx_cli.dart barrel
import 'package:fx_cli/fx_cli.dart';

void main() {
  late StringBuffer buffer;
  late OutputFormatter formatter;

  setUp(() {
    buffer = StringBuffer();
    formatter = OutputFormatter(buffer);
  });

  Project makeProject(
    String name, {
    ProjectType type = ProjectType.dartPackage,
    List<String> deps = const [],
  }) => Project(
    name: name,
    path: '/ws/packages/$name',
    type: type,
    dependencies: deps,
    targets: {},
  );

  group('OutputFormatter basic', () {
    test('writeln writes line to sink', () {
      formatter.writeln('hello');
      expect(buffer.toString(), equals('hello\n'));
    });

    test('writeln with no argument writes empty line', () {
      formatter.writeln();
      expect(buffer.toString(), equals('\n'));
    });

    test('write writes without newline', () {
      formatter.write('inline');
      expect(buffer.toString(), equals('inline'));
    });
  });

  group('OutputFormatter.writeProjectTable', () {
    test('prints table with project info', () {
      final projects = [makeProject('pkg_a'), makeProject('pkg_b')];
      formatter.writeProjectTable(projects);
      final output = buffer.toString();

      expect(output, contains('pkg_a'));
      expect(output, contains('pkg_b'));
      expect(output, contains('NAME'));
      expect(output, contains('TYPE'));
      expect(output, contains('PATH'));
    });

    test('prints "No projects found." for empty list', () {
      formatter.writeProjectTable([]);
      expect(buffer.toString(), contains('No projects found'));
    });

    test('includes project type in output', () {
      final projects = [makeProject('app', type: ProjectType.flutterApp)];
      formatter.writeProjectTable(projects);
      expect(buffer.toString(), contains('flutter_app'));
    });

    test('includes project path in output', () {
      final projects = [makeProject('pkg_a')];
      formatter.writeProjectTable(projects);
      expect(buffer.toString(), contains('/ws/packages/pkg_a'));
    });

    test('shows all project types correctly', () {
      final projects = [
        makeProject('d', type: ProjectType.dartPackage),
        makeProject('fp', type: ProjectType.flutterPackage),
        makeProject('fa', type: ProjectType.flutterApp),
        makeProject('cli', type: ProjectType.dartCli),
      ];
      formatter.writeProjectTable(projects);
      final output = buffer.toString();
      expect(output, contains('dart_package'));
      expect(output, contains('flutter_package'));
      expect(output, contains('flutter_app'));
      expect(output, contains('dart_cli'));
    });
  });

  group('OutputFormatter.writeProjectJson', () {
    test('outputs valid JSON array', () {
      final projects = [makeProject('pkg_a'), makeProject('pkg_b')];
      formatter.writeProjectJson(projects);

      final data = jsonDecode(buffer.toString()) as List;
      expect(data, hasLength(2));
    });

    test('each entry has name, type, path, dependencies', () {
      final projects = [
        makeProject('pkg_a', deps: ['dep1']),
      ];
      formatter.writeProjectJson(projects);

      final data = jsonDecode(buffer.toString()) as List;
      final entry = data.first as Map;
      expect(entry['name'], equals('pkg_a'));
      expect(entry['type'], equals('dart_package'));
      expect(entry['path'], equals('/ws/packages/pkg_a'));
      expect(entry['dependencies'], contains('dep1'));
    });

    test('empty list produces empty JSON array', () {
      formatter.writeProjectJson([]);
      final data = jsonDecode(buffer.toString()) as List;
      expect(data, isEmpty);
    });
  });

  group('OutputFormatter.writeGraphText', () {
    test('prints dependency arrows', () {
      final projects = [
        makeProject('core'),
        makeProject('app', deps: ['core']),
      ];
      final graph = ProjectGraph.build(projects);
      formatter.writeGraphText(graph, projects);

      final output = buffer.toString();
      expect(output, contains('app'));
      expect(output, contains('core'));
      expect(output, contains('→'));
    });

    test('prints project without deps (no arrow)', () {
      final projects = [makeProject('standalone')];
      final graph = ProjectGraph.build(projects);
      formatter.writeGraphText(graph, projects);

      final output = buffer.toString();
      expect(output, contains('standalone'));
      expect(output, isNot(contains('→')));
    });

    test('prints "No projects found." for empty list', () {
      final graph = ProjectGraph.build([]);
      formatter.writeGraphText(graph, []);
      expect(buffer.toString(), contains('No projects found'));
    });
  });

  group('OutputFormatter.writeGraphJson', () {
    test('outputs nodes and edges', () {
      final projects = [
        makeProject('core'),
        makeProject('app', deps: ['core']),
      ];
      final graph = ProjectGraph.build(projects);
      formatter.writeGraphJson(graph, projects);

      final data = jsonDecode(buffer.toString()) as Map;
      expect(data.containsKey('nodes'), isTrue);
      expect(data.containsKey('edges'), isTrue);

      final nodes = (data['nodes'] as List).cast<String>();
      expect(nodes, containsAll(['core', 'app']));

      final edges = data['edges'] as List;
      expect(edges, hasLength(1));
      final edge = edges.first as Map;
      expect(edge['from'], equals('app'));
      expect(edge['to'], equals('core'));
    });

    test('no edges for independent projects', () {
      final projects = [makeProject('a'), makeProject('b')];
      final graph = ProjectGraph.build(projects);
      formatter.writeGraphJson(graph, projects);

      final data = jsonDecode(buffer.toString()) as Map;
      expect((data['edges'] as List), isEmpty);
    });
  });

  group('OutputFormatter.writeGraphDot', () {
    test('produces valid DOT format', () {
      final projects = [
        makeProject('core'),
        makeProject('app', deps: ['core']),
      ];
      final graph = ProjectGraph.build(projects);
      formatter.writeGraphDot(graph, projects);

      final output = buffer.toString();
      expect(output, contains('digraph'));
      expect(output, contains('rankdir=LR'));
      expect(output, contains('"app" -> "core"'));
      expect(output, contains('}'));
    });

    test('lists all nodes even without edges', () {
      final projects = [makeProject('solo')];
      final graph = ProjectGraph.build(projects);
      formatter.writeGraphDot(graph, projects);

      final output = buffer.toString();
      expect(output, contains('"solo"'));
      expect(output, isNot(contains('->')));
    });
  });
}
