import 'package:fx_core/fx_core.dart';

import 'task_result.dart';

/// Interface for pluggable task executors.
///
/// Implement this to create custom executors that can be registered with
/// [ExecutorRegistry] and referenced in target configs via `plugin:<name>`.
abstract class ExecutorPlugin {
  /// Unique name for this executor (used in `plugin:<name>` syntax).
  String get name;

  /// Human-readable description.
  String get description;

  /// Execute the target on the given project.
  Future<TaskResult> execute({
    required Project project,
    required Target target,
    required Map<String, dynamic> options,
    required String workspaceRoot,
  });
}
