import 'package:fx_core/fx_core.dart';

/// A group of projects that share the same executor and can be batched
/// into a single process invocation.
class BatchGroup {
  final String executor;
  final List<Project> projects;

  const BatchGroup({required this.executor, required this.projects});

  @override
  String toString() =>
      'BatchGroup(executor: $executor, projects: ${projects.map((p) => p.name).join(', ')})';
}

/// Groups independent projects by executor command for batch execution.
///
/// When multiple projects share the same executor (e.g., `dart test`),
/// they can be combined into a single invocation to reduce process startup
/// overhead. Only executors known to support multi-directory invocation
/// are batched.
class BatchGrouper {
  /// Executor prefixes that support batch invocation.
  ///
  /// These commands can accept multiple paths/packages in a single call.
  static const defaultBatchableExecutors = {
    'dart test',
    'dart analyze',
    'flutter test',
    'dart format',
  };

  /// Groups [entries] by executor, returning batchable groups and unbatchable
  /// singles.
  ///
  /// A project is batchable if:
  /// 1. Its executor matches a known batchable prefix
  /// 2. The target has `batchable` not explicitly set to false in options
  /// 3. At least one other project shares the same executor
  static List<BatchGroup> group(
    List<BatchEntry> entries, {
    Set<String>? batchableExecutors,
  }) {
    final allowed = batchableExecutors ?? defaultBatchableExecutors;
    final groups = <String, List<Project>>{};
    final singles = <_BatchEntry>[];

    for (final entry in entries) {
      final isBatchable =
          entry.target.options['batchable'] != false &&
          allowed.any((prefix) => entry.target.executor.startsWith(prefix));

      if (isBatchable) {
        groups.putIfAbsent(entry.target.executor, () => []);
        groups[entry.target.executor]!.add(entry.project);
      } else {
        singles.add(entry);
      }
    }

    final result = <BatchGroup>[];

    // Add batch groups (only group if 2+ projects share executor)
    for (final entry in groups.entries) {
      if (entry.value.length >= 2) {
        result.add(BatchGroup(executor: entry.key, projects: entry.value));
      } else {
        // Single project — no benefit from batching
        result.add(BatchGroup(executor: entry.key, projects: entry.value));
      }
    }

    // Add non-batchable as individual groups
    for (final single in singles) {
      result.add(
        BatchGroup(
          executor: single.target.executor,
          projects: [single.project],
        ),
      );
    }

    return result;
  }
}

/// Internal pairing of a project with its resolved target.
class BatchEntry {
  final Project project;
  final Target target;

  const BatchEntry({required this.project, required this.target});
}

// Alias for internal use in BatchGrouper
typedef _BatchEntry = BatchEntry;
