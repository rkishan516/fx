import 'package:fx_core/fx_core.dart';

/// Configuration for distributed task execution.
class DistributedConfig {
  final int totalWorkers;
  final int workerIndex;

  DistributedConfig({required this.totalWorkers, required this.workerIndex}) {
    if (totalWorkers < 1) {
      throw ArgumentError('totalWorkers must be >= 1, got $totalWorkers');
    }
    if (workerIndex < 0 || workerIndex >= totalWorkers) {
      throw ArgumentError(
        'workerIndex must be in [0, $totalWorkers), got $workerIndex',
      );
    }
  }
}

/// Partitions projects across multiple workers for distributed execution.
///
/// Uses a dependency-aware round-robin strategy: projects are sorted
/// topologically, then assigned to partitions in round-robin fashion.
/// This ensures each partition has a roughly equal number of projects
/// while maintaining dependency ordering within each partition.
class TaskPartitioner {
  /// Partition [projects] into [numPartitions] groups.
  ///
  /// Projects are distributed via round-robin in topological order.
  /// Each partition maintains topological ordering internally.
  static List<List<Project>> partition(
    List<Project> projects,
    int numPartitions,
  ) {
    final partitions = List.generate(numPartitions, (_) => <Project>[]);

    // Sort projects topologically (dependencies first)
    final sorted = _topologicalSort(projects);

    // Round-robin assignment
    for (var i = 0; i < sorted.length; i++) {
      partitions[i % numPartitions].add(sorted[i]);
    }

    return partitions;
  }

  /// Get the partition at [index] from [numPartitions] total.
  static List<Project> getPartition(
    List<Project> projects,
    int numPartitions,
    int index,
  ) {
    if (index < 0 || index >= numPartitions) {
      throw ArgumentError('index must be in [0, $numPartitions), got $index');
    }
    return partition(projects, numPartitions)[index];
  }

  /// Simple topological sort using Kahn's algorithm.
  static List<Project> _topologicalSort(List<Project> projects) {
    final projectMap = {for (final p in projects) p.name: p};
    final inDegree = <String, int>{};
    final adjacency = <String, List<String>>{};

    for (final p in projects) {
      inDegree.putIfAbsent(p.name, () => 0);
      adjacency.putIfAbsent(p.name, () => []);
      for (final dep in p.dependencies) {
        if (projectMap.containsKey(dep)) {
          inDegree[p.name] = (inDegree[p.name] ?? 0) + 1;
          adjacency.putIfAbsent(dep, () => []);
          adjacency[dep]!.add(p.name);
        }
      }
    }

    final queue = inDegree.entries
        .where((e) => e.value == 0)
        .map((e) => e.key)
        .toList();
    final sorted = <Project>[];

    while (queue.isNotEmpty) {
      final name = queue.removeAt(0);
      sorted.add(projectMap[name]!);

      final dependents = adjacency[name] ?? <String>[];
      for (final dependent in dependents) {
        inDegree[dependent] = inDegree[dependent]! - 1;
        if (inDegree[dependent] == 0) {
          queue.add(dependent);
        }
      }
    }

    // Add any remaining projects (shouldn't happen without cycles)
    for (final p in projects) {
      if (!sorted.contains(p)) sorted.add(p);
    }

    return sorted;
  }
}
