import 'package:fx_core/fx_core.dart';

import 'executor_registry.dart';
import 'process_runner.dart';
import 'task_result.dart';

/// Executes a single target on a single project.
///
/// Supports both process-based execution (plain string executors) and
/// plugin-based execution (`plugin:<name>` executors).
class TaskExecutor {
  final ProcessRunner processRunner;
  final ExecutorRegistry? executorRegistry;
  final String workspaceRoot;

  const TaskExecutor({
    required this.processRunner,
    this.executorRegistry,
    this.workspaceRoot = '.',
  });

  /// Execute [targetName] on [project] using [executor] command.
  ///
  /// If [configurationName] is provided, it selects a named configuration
  /// preset from the target's `configurations` map, merging those options
  /// on top of the base options.
  Future<TaskResult> execute({
    required Project project,
    required String targetName,
    required String executor,
    String? configurationName,
  }) async {
    // Check for plugin executor
    if (ExecutorRegistry.isPluginExecutor(executor)) {
      return _executePlugin(project, targetName, executor, configurationName);
    }

    return _executeProcess(project, targetName, executor, configurationName);
  }

  Future<TaskResult> _executeProcess(
    Project project,
    String targetName,
    String executor,
    String? configurationName,
  ) async {
    final start = DateTime.now();

    // Parse executor into executable + arguments
    final parts = executor.split(' ');
    final executable = parts.first;
    final arguments = parts.skip(1).toList();

    // Resolve configuration options and pass as environment variables
    final target = project.targets[targetName];
    Map<String, String>? environment;
    if (target != null) {
      final resolved = target.resolveOptions(configName: configurationName);
      if (resolved.isNotEmpty) {
        environment = resolved.map(
          (k, v) => MapEntry('FX_OPT_${k.toUpperCase()}', v.toString()),
        );
      }
    }

    final call = ProcessCall(
      executable: executable,
      arguments: arguments,
      workingDirectory: project.path,
      environment: environment,
    );

    final processResult = await processRunner.run(call);
    final duration = DateTime.now().difference(start);

    return TaskResult(
      projectName: project.name,
      targetName: targetName,
      status: processResult.exitCode == 0
          ? TaskStatus.success
          : TaskStatus.failure,
      exitCode: processResult.exitCode,
      stdout: processResult.stdout,
      stderr: processResult.stderr,
      duration: duration,
    );
  }

  Future<TaskResult> _executePlugin(
    Project project,
    String targetName,
    String executor,
    String? configurationName,
  ) async {
    final pluginName = ExecutorRegistry.extractPluginName(executor);
    final plugin = executorRegistry?.get(pluginName);

    if (plugin == null) {
      return TaskResult(
        projectName: project.name,
        targetName: targetName,
        status: TaskStatus.failure,
        exitCode: 1,
        stdout: '',
        stderr:
            'Executor plugin "$pluginName" not found. '
            'Available plugins: ${executorRegistry?.names.join(', ') ?? 'none'}',
        duration: Duration.zero,
      );
    }

    final target =
        project.targets[targetName] ??
        Target(name: targetName, executor: executor);

    return plugin.execute(
      project: project,
      target: target,
      options: target.resolveOptions(configName: configurationName),
      workspaceRoot: workspaceRoot,
    );
  }
}
