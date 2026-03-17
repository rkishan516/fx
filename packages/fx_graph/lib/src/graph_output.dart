import 'dart:convert';

import 'project_graph.dart';
import 'task_graph.dart';

/// Formats a [ProjectGraph] in various output formats.
class GraphOutput {
  /// Output as JSON adjacency list.
  static String toJson(ProjectGraph graph) {
    final nodes = graph.nodes.toList()..sort();
    final edges = <Map<String, String>>[];

    for (final node in nodes) {
      for (final dep in graph.dependenciesOf(node)) {
        edges.add({'from': node, 'to': dep});
      }
    }

    return const JsonEncoder.withIndent('  ').convert({
      'nodes': nodes,
      'edges': edges,
      'adjacency': {
        for (final node in nodes)
          node: graph.dependenciesOf(node).toList()..sort(),
      },
    });
  }

  /// Output as DOT format (Graphviz).
  static String toDot(ProjectGraph graph) {
    final buf = StringBuffer();
    buf.writeln('digraph fx_workspace {');
    buf.writeln('  rankdir=LR;');
    buf.writeln('  node [shape=box];');

    final nodes = graph.nodes.toList()..sort();
    for (final node in nodes) {
      buf.writeln('  "$node";');
      for (final dep in (graph.dependenciesOf(node).toList()..sort())) {
        buf.writeln('  "$node" -> "$dep";');
      }
    }

    buf.writeln('}');
    return buf.toString();
  }

  /// Output a [TaskGraph] as JSON.
  static String taskGraphToJson(TaskGraph graph) =>
      const JsonEncoder.withIndent('  ').convert(graph.toJson());

  /// Output a [TaskGraph] as Graphviz DOT format.
  static String taskGraphToDot(TaskGraph graph) => graph.toDot();

  /// Output a [TaskGraph] as human-readable text.
  static String taskGraphToText(TaskGraph graph) {
    final buf = StringBuffer();
    if (graph.nodes.isEmpty) {
      return 'No targets defined in workspace configuration.';
    }
    buf.writeln('Task Execution Graph:');
    buf.writeln('');
    for (final node in graph.nodes) {
      if (node.dependsOn.isEmpty) {
        buf.writeln('  ${node.id}');
      } else {
        buf.writeln('  ${node.id}  ← depends on: ${node.dependsOn.join(', ')}');
      }
    }
    return buf.toString().trimRight();
  }

  /// Output as human-readable text.
  static String toText(ProjectGraph graph) {
    final buf = StringBuffer();
    final nodes = graph.nodes.toList()..sort();

    for (final node in nodes) {
      final deps = graph.dependenciesOf(node).toList()..sort();
      if (deps.isEmpty) {
        buf.writeln('$node (no dependencies)');
      } else {
        buf.writeln('$node -> ${deps.join(', ')}');
      }
    }

    return buf.toString().trimRight();
  }
}
