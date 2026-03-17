import '../models/project.dart';
import '../models/target.dart';

/// Metadata about a task run, exposed to plugins via [PluginHook.createMetadata].
class TaskRunMetadata {
  final String targetName;
  final List<Project> projects;
  final Map<String, dynamic> extra;

  const TaskRunMetadata({
    required this.targetName,
    required this.projects,
    this.extra = const {},
  });
}

/// Inferred cache configuration for a target on a project.
class InferredCacheConfig {
  /// Input patterns to include in cache hash.
  final List<String> inputs;

  /// Output patterns for cached artifacts.
  final List<String> outputs;

  const InferredCacheConfig({this.inputs = const [], this.outputs = const []});
}

/// Abstract interface for fx plugin hooks.
///
/// A plugin hook can participate in project discovery, dependency inference,
/// and cache configuration inference. Implement only the methods relevant
/// to the plugin.
///
/// This is the Dart-native equivalent of Nx's `createNodes`/`createDependencies`
/// APIs, unified into a single interface since fx is Dart-only.
abstract class PluginHook {
  /// Unique name identifying this plugin hook.
  String get name;

  /// Glob pattern for files that this hook is interested in.
  ///
  /// Only files matching this pattern will be passed to [inferProjects].
  String get fileGlob;

  /// Infer additional projects from files matching [fileGlob].
  ///
  /// [workspaceRoot] is the absolute path to the workspace root.
  /// [matchedFiles] is the list of files matching [fileGlob] within the workspace.
  ///
  /// Returns a list of inferred [Project] instances. Projects whose names
  /// conflict with pubspec.yaml-discovered projects are silently skipped.
  Future<List<Project>> inferProjects(
    String workspaceRoot,
    List<String> matchedFiles,
  );

  /// Infer additional dependency edges between [projects].
  ///
  /// Returns a map of `{ projectName: [depProjectName, ...] }`.
  /// Edges that already exist from pubspec.yaml are not duplicated.
  Future<Map<String, List<String>>> inferDependencies(List<Project> projects);

  /// Infer cache inputs/outputs for a target on a project.
  ///
  /// Plugins can analyze tool config files (e.g., build.yaml, test configs)
  /// to suggest appropriate cache inputs and outputs for targets they create
  /// or enhance. Returns null if the plugin has no opinion.
  ///
  /// This serves as the lowest priority in the merge order:
  ///   plugin-inferred < targetDefaults < workspace targets < project targets
  Future<InferredCacheConfig?> inferCacheConfig(
    Project project,
    Target target,
  ) async => null;

  /// Called before task execution begins.
  ///
  /// Plugins can use this to set up resources, start services, or validate
  /// preconditions. Return false to abort execution.
  Future<bool> preTasksExecution(TaskRunMetadata metadata) async => true;

  /// Called after all tasks have completed.
  ///
  /// Plugins can use this to clean up resources, aggregate results, or
  /// send notifications. [results] contains the outcome of each task.
  Future<void> postTasksExecution(
    TaskRunMetadata metadata,
    List<Map<String, dynamic>> results,
  ) async {}

  /// Create custom metadata to attach to task results.
  ///
  /// Called once per task run. Returns a map of metadata that plugins
  /// want to record (e.g., timing info, environment details, commit hashes).
  Future<Map<String, dynamic>> createMetadata(TaskRunMetadata metadata) async =>
      const {};
}
