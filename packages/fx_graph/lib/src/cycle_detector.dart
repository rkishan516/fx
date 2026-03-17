import 'project_graph.dart';

/// Cycle detection using DFS with node coloring.
class CycleDetector {
  /// Whether the graph contains any cycle.
  static bool hasCycle(ProjectGraph graph) => findCycles(graph).isNotEmpty;

  /// Find all cycles in the graph.
  ///
  /// Returns a list of cycles, where each cycle is a list of node names
  /// forming the cycle path.
  static List<List<String>> findCycles(ProjectGraph graph) {
    final white = <String>{}; // unvisited
    final gray = <String>{}; // in current DFS path
    final black = <String>{}; // fully processed

    final cycles = <List<String>>[];

    white.addAll(graph.nodes);

    void dfs(String node, List<String> path) {
      white.remove(node);
      gray.add(node);
      path.add(node);

      for (final dep in graph.dependenciesOf(node)) {
        if (black.contains(dep)) continue;

        if (gray.contains(dep)) {
          // Found a cycle — extract it
          final cycleStart = path.indexOf(dep);
          final cycle = path.sublist(cycleStart).toList();
          cycles.add(cycle);
          continue;
        }

        if (white.contains(dep)) {
          dfs(dep, List<String>.from(path));
        }
      }

      path.removeLast();
      gray.remove(node);
      black.add(node);
    }

    for (final node in List<String>.from(graph.nodes)) {
      if (white.contains(node)) {
        dfs(node, []);
      }
    }

    return cycles;
  }
}
