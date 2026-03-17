import 'package:fx_core/fx_core.dart';

import 'project_graph.dart';

/// Topological sort using Kahn's algorithm (BFS-based).
class TopologicalSort {
  /// Sort [projects] in topological order (dependencies before dependents).
  ///
  /// Returns a list where each project appears before any project that
  /// depends on it (i.e., leaf nodes come first).
  ///
  /// Throws [StateError] if a cycle is detected.
  static List<Project> sort(List<Project> projects, ProjectGraph graph) {
    if (projects.isEmpty) return [];

    final projectMap = {for (final p in projects) p.name: p};

    // Count in-degrees (number of dependencies within our project set)
    final inDegree = <String, int>{};
    for (final p in projects) {
      inDegree[p.name] = 0;
    }
    for (final p in projects) {
      for (final dep in graph.dependenciesOf(p.name)) {
        if (inDegree.containsKey(dep)) {
          // p depends on dep, so dep's in-degree in the reverse sense doesn't change
          // We track: in-degree = number of unresolved deps of this node
        }
      }
    }

    // Rebuild in-degree as: number of deps that are also in the project set
    final inDegreeMap = <String, int>{};
    for (final p in projects) {
      final depsInSet = graph
          .dependenciesOf(p.name)
          .where(inDegree.containsKey)
          .length;
      inDegreeMap[p.name] = depsInSet;
    }

    // Start with nodes that have no in-set dependencies
    final queue = <String>[
      ...inDegreeMap.entries.where((e) => e.value == 0).map((e) => e.key),
    ];

    final result = <Project>[];

    while (queue.isNotEmpty) {
      // Sort for deterministic output
      queue.sort();
      final current = queue.removeAt(0);
      result.add(projectMap[current]!);

      // Reduce in-degree for all projects that depend on current
      for (final dependent in graph.dependentsOf(current)) {
        if (!inDegreeMap.containsKey(dependent)) continue;
        inDegreeMap[dependent] = inDegreeMap[dependent]! - 1;
        if (inDegreeMap[dependent] == 0) {
          queue.add(dependent);
        }
      }
    }

    if (result.length != projects.length) {
      throw StateError(
        'Cycle detected in project dependencies. '
        'Use `fx graph` to inspect the dependency graph.',
      );
    }

    return result;
  }
}
