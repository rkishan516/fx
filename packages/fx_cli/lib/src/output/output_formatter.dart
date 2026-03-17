import 'dart:convert';

import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';

/// Formats CLI output as human-readable text or JSON.
class OutputFormatter {
  final StringSink sink;

  OutputFormatter(this.sink);

  void writeln([String line = '']) => sink.writeln(line);

  void write(String text) => sink.write(text);

  /// Writes a list of projects as a formatted table.
  void writeProjectTable(List<Project> projects) {
    if (projects.isEmpty) {
      writeln('No projects found.');
      return;
    }

    final nameWidth =
        projects.map((p) => p.name.length).reduce((a, b) => a > b ? a : b) + 2;
    final typeWidth = 16;

    writeln('${'NAME'.padRight(nameWidth)}${'TYPE'.padRight(typeWidth)}PATH');
    writeln('-' * (nameWidth + typeWidth + 40));

    for (final project in projects) {
      final typeName = _projectTypeName(project.type);
      writeln(
        '${project.name.padRight(nameWidth)}${typeName.padRight(typeWidth)}${project.path}',
      );
    }
  }

  /// Writes a list of projects as a JSON array.
  void writeProjectJson(List<Project> projects) {
    final data = projects
        .map(
          (p) => {
            'name': p.name,
            'type': _projectTypeName(p.type),
            'path': p.path,
            'dependencies': p.dependencies,
          },
        )
        .toList();
    writeln(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Writes the project graph in text format.
  void writeGraphText(ProjectGraph graph, List<Project> projects) {
    if (projects.isEmpty) {
      writeln('No projects found.');
      return;
    }
    writeln('Project dependency graph:');
    for (final project in projects) {
      final deps = graph.dependenciesOf(project.name);
      if (deps.isEmpty) {
        writeln('  ${project.name}');
      } else {
        writeln('  ${project.name} → ${deps.join(', ')}');
      }
    }
  }

  /// Writes the project graph as a JSON adjacency list.
  void writeGraphJson(ProjectGraph graph, List<Project> projects) {
    final nodes = projects.map((p) => p.name).toList();
    final edges = <Map<String, String>>[];

    for (final project in projects) {
      for (final dep in graph.dependenciesOf(project.name)) {
        edges.add({'from': project.name, 'to': dep});
      }
    }

    final data = {'nodes': nodes, 'edges': edges};
    writeln(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Writes the project graph in Graphviz DOT format.
  void writeGraphDot(ProjectGraph graph, List<Project> projects) {
    writeln('digraph fx_workspace {');
    writeln('  rankdir=LR;');
    for (final project in projects) {
      writeln('  "${project.name}";');
    }
    for (final project in projects) {
      for (final dep in graph.dependenciesOf(project.name)) {
        writeln('  "${project.name}" -> "$dep";');
      }
    }
    writeln('}');
  }

  String _projectTypeName(ProjectType type) {
    return switch (type) {
      ProjectType.dartPackage => 'dart_package',
      ProjectType.flutterPackage => 'flutter_package',
      ProjectType.flutterApp => 'flutter_app',
      ProjectType.dartCli => 'dart_cli',
    };
  }
}
