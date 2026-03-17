import 'dart:async';
import 'dart:io';

import 'package:fx_core/fx_core.dart';

import 'batch_grouper.dart';
import 'continuous_task_manager.dart';
import 'process_runner.dart';
import 'task_executor.dart';
import 'task_pipeline.dart';
import 'task_result.dart';

/// Orchestrates task execution across multiple projects.
///
/// Accepts a pre-sorted list of projects (sorted by the caller using
/// topological sort from fx_graph). Handles parallelism, pipeline
/// (dependsOn) resolution, and skip-on-failure logic.
///
/// Projects with no unresolved dependencies run concurrently, up to
/// [concurrency] at a time. Dependent projects wait until their
/// dependencies complete.
class TaskRunner {
  final ProcessRunner processRunner;
  final FxConfig config;
  final int concurrency;

  /// Plugin hooks to call during task lifecycle.
  final List<PluginHook> pluginHooks;

  TaskRunner({
    required this.processRunner,
    required this.config,
    int? concurrency,
    this.batch = false,
    this.pluginHooks = const [],
  }) : concurrency = concurrency ?? Platform.numberOfProcessors;

  /// Tracks which transitive target runs have been completed to avoid duplicates.
  final _completedTransitive = <String>{};

  /// Whether to use batch execution mode.
  ///
  /// When enabled, independent projects sharing the same executor for a
  /// pipeline target are grouped and executed together rather than
  /// individually. This reduces process startup overhead.
  final bool batch;

  /// Run [targetName] across [projects] (in the provided order).
  ///
  /// [failedProjects] is a mutable set that tracks which projects have
  /// failed; used to skip dependents. Pass a fresh `{}` or an existing set.
  /// [continuousManager] can be injected for testing.
  Future<List<TaskResult>> run({
    required List<Project> projects,
    required String targetName,
    Set<String>? failedProjects,
    bool bail = false,
    ContinuousTaskManager? continuousManager,
    String? configurationName,
    bool excludeTaskDependencies = false,
  }) async {
    failedProjects ??= {};
    _completedTransitive.clear();
    final executor = TaskExecutor(processRunner: processRunner);
    final pipeline = excludeTaskDependencies
        ? [targetName]
        : TaskPipeline.resolve(targetName, config);
    continuousManager ??= ContinuousTaskManager();

    final metadata = TaskRunMetadata(
      targetName: targetName,
      projects: projects,
    );

    // Call preTasksExecution hooks
    for (final hook in pluginHooks) {
      final proceed = await hook.preTasksExecution(metadata);
      if (!proceed) return [];
    }

    // Collect plugin metadata
    final pluginMetadata = <String, dynamic>{};
    for (final hook in pluginHooks) {
      final m = await hook.createMetadata(metadata);
      pluginMetadata.addAll(m);
    }

    List<TaskResult> results;
    try {
      if (concurrency <= 1) {
        results = await _runSequential(
          projects,
          pipeline,
          executor,
          failedProjects,
          bail,
          continuousManager: continuousManager,
          configurationName: configurationName,
        );
      } else {
        results = await _runParallel(
          projects,
          pipeline,
          executor,
          failedProjects,
          bail,
          continuousManager: continuousManager,
          configurationName: configurationName,
        );
      }
      // Collect any crashed continuous processes
      final crashes = await continuousManager.collectCrashes();
      results.addAll(crashes);
    } finally {
      await continuousManager.shutdown();
    }

    // Call postTasksExecution hooks
    final resultMaps = results
        .map(
          (r) => {
            'projectName': r.projectName,
            'targetName': r.targetName,
            'status': r.status.name,
            'exitCode': r.exitCode,
            'duration': r.duration.inMilliseconds,
            ...pluginMetadata,
          },
        )
        .toList();
    for (final hook in pluginHooks) {
      await hook.postTasksExecution(metadata, resultMaps);
    }

    return results;
  }

  /// Sequential execution — simple loop, same as before.
  Future<List<TaskResult>> _runSequential(
    List<Project> projects,
    List<String> pipeline,
    TaskExecutor executor,
    Set<String> failedProjects,
    bool bail, {
    ContinuousTaskManager? continuousManager,
    String? configurationName,
  }) async {
    if (batch && pipeline.length == 1) {
      return _runSequentialBatched(
        projects,
        pipeline.first,
        executor,
        failedProjects,
        bail,
      );
    }

    final results = <TaskResult>[];
    for (final project in projects) {
      final projectResults = await _runProject(
        project,
        projects,
        pipeline,
        executor,
        failedProjects,
        continuousManager: continuousManager,
        configurationName: configurationName,
      );
      results.addAll(projectResults);
      if (bail && projectResults.any((r) => r.isFailure)) return results;
    }
    return results;
  }

  /// Sequential batch execution — groups projects by executor and runs batches.
  Future<List<TaskResult>> _runSequentialBatched(
    List<Project> projects,
    String targetName,
    TaskExecutor executor,
    Set<String> failedProjects,
    bool bail,
  ) async {
    final results = <TaskResult>[];

    // Build batch entries for projects that have this target
    final entries = <BatchEntry>[];
    final skipped = <TaskResult>[];

    for (final project in projects) {
      // Check if dependency failed
      final depFailed = project.dependencies.any(
        (dep) => failedProjects.contains(dep),
      );
      if (depFailed) {
        skipped.add(
          TaskResult.skipped(
            projectName: project.name,
            targetName: targetName,
            reason:
                'Skipped because a dependency failed: ${project.dependencies.where((d) => failedProjects.contains(d)).join(', ')}',
          ),
        );
        continue;
      }

      final execCommand = _resolveExecutor(project, targetName);
      if (execCommand.isEmpty) {
        skipped.add(
          TaskResult.skipped(
            projectName: project.name,
            targetName: targetName,
            reason: 'No executor configured for target "$targetName"',
          ),
        );
        continue;
      }

      final target =
          project.targets[targetName] ??
          config.targets[targetName] ??
          Target(name: targetName, executor: execCommand);
      entries.add(BatchEntry(project: project, target: target));
    }

    results.addAll(skipped);

    if (entries.isEmpty) return results;

    final groups = BatchGrouper.group(entries);
    for (final group in groups) {
      if (group.projects.length >= 2) {
        final batchResults = await _runBatch(group, targetName, executor);
        results.addAll(batchResults);
        if (batchResults.any((r) => r.isFailure)) {
          for (final p in group.projects) {
            failedProjects.add(p.name);
          }
        }
      } else {
        // Single project — run normally
        final project = group.projects.first;
        final result = await executor.execute(
          project: project,
          targetName: targetName,
          executor: group.executor,
        );
        results.add(result);
        if (result.isFailure) failedProjects.add(project.name);
      }
      if (bail && results.any((r) => r.isFailure)) return results;
    }

    return results;
  }

  /// Parallel execution with concurrency limit.
  ///
  /// Uses a ready-queue approach: projects whose dependencies are all
  /// completed (or not in the run set) are eligible to run. Up to
  /// [concurrency] projects execute simultaneously.
  Future<List<TaskResult>> _runParallel(
    List<Project> projects,
    List<String> pipeline,
    TaskExecutor executor,
    Set<String> failedProjects,
    bool bail, {
    ContinuousTaskManager? continuousManager,
    String? configurationName,
  }) async {
    final results = <TaskResult>[];
    final projectNames = projects.map((p) => p.name).toSet();
    final completed = <String>{};
    final pending = List<Project>.from(projects);
    final inFlight = <String, Future<List<TaskResult>>>{};
    var bailed = false;

    while (pending.isNotEmpty || inFlight.isNotEmpty) {
      if (bailed) {
        // Drain in-flight and stop scheduling
        if (inFlight.isNotEmpty) {
          final done = await Future.any(
            inFlight.values.map((f) => f.then((_) => true)),
          );
          if (done) {
            await _collectCompleted(
              inFlight,
              completed,
              results,
              failedProjects,
            );
          }
        }
        if (inFlight.isEmpty) break;
        continue;
      }

      // Find projects ready to run (all deps satisfied or not in run set)
      final ready = <Project>[];
      for (final project in pending) {
        final depsInSet = project.dependencies.where(
          (d) => projectNames.contains(d),
        );
        if (depsInSet.every((d) => completed.contains(d))) {
          ready.add(project);
        }
      }

      // Launch ready projects up to concurrency limit
      for (final project in ready) {
        if (inFlight.length >= concurrency) break;

        // Check if this target requires exclusive execution (parallelism: false)
        final resolvedTarget = config.resolveTarget(
          pipeline.last,
          projectTarget: project.targets.isEmpty
              ? null
              : project.targets[pipeline.last],
        );
        final requiresExclusive =
            resolvedTarget != null && !resolvedTarget.parallelism;

        if (requiresExclusive && inFlight.isNotEmpty) {
          // Wait for all in-flight tasks to finish before running exclusive task
          break;
        }

        pending.remove(project);
        inFlight[project.name] = _runProject(
          project,
          projects,
          pipeline,
          executor,
          failedProjects,
          continuousManager: continuousManager,
          configurationName: configurationName,
        );

        if (requiresExclusive) {
          // Don't launch more tasks alongside an exclusive task
          break;
        }
      }

      // Wait for at least one to complete
      if (inFlight.isNotEmpty) {
        await _collectCompleted(inFlight, completed, results, failedProjects);
        if (bail && results.any((r) => r.isFailure)) bailed = true;
      } else if (pending.isNotEmpty) {
        // Deadlock safety: if nothing is ready and nothing is in-flight,
        // force the first pending project through (breaks cycles)
        final forced = pending.removeAt(0);
        final forcedResults = await _runProject(
          forced,
          projects,
          pipeline,
          executor,
          failedProjects,
          continuousManager: continuousManager,
          configurationName: configurationName,
        );
        results.addAll(forcedResults);
        completed.add(forced.name);
        if (bail && forcedResults.any((r) => r.isFailure)) break;
      }
    }

    return results;
  }

  /// Waits for the first in-flight future to complete and collects results.
  Future<void> _collectCompleted(
    Map<String, Future<List<TaskResult>>> inFlight,
    Set<String> completed,
    List<TaskResult> results,
    Set<String> failedProjects,
  ) async {
    // Wait for any one to complete
    final completer = Completer<String>();
    for (final entry in inFlight.entries) {
      entry.value.then((_) {
        if (!completer.isCompleted) completer.complete(entry.key);
      });
    }
    final doneName = await completer.future;

    final doneResults = await inFlight.remove(doneName)!;
    results.addAll(doneResults);
    completed.add(doneName);
    if (doneResults.any((r) => r.isFailure)) {
      failedProjects.add(doneName);
    }

    // Also collect any others that have already completed
    final otherDone = <String>[];
    for (final entry in inFlight.entries) {
      // Check if the future is already resolved by using a non-blocking probe
      var resolved = false;
      unawaited(
        entry.value.then((_) {
          resolved = true;
        }),
      );
      await Future.microtask(() {});
      if (resolved) otherDone.add(entry.key);
    }
    for (final name in otherDone) {
      final r = await inFlight.remove(name)!;
      results.addAll(r);
      completed.add(name);
      if (r.any((r) => r.isFailure)) failedProjects.add(name);
    }
  }

  /// Run all pipeline targets for a single project.
  Future<List<TaskResult>> _runProject(
    Project project,
    List<Project> allProjects,
    List<String> pipeline,
    TaskExecutor executor,
    Set<String> failedProjects, {
    ContinuousTaskManager? continuousManager,
    String? configurationName,
  }) async {
    final results = <TaskResult>[];

    // Check if any dependency of this project failed
    final depFailed = project.dependencies.any(
      (dep) => failedProjects.contains(dep),
    );
    if (depFailed) {
      for (final t in pipeline) {
        results.add(
          TaskResult.skipped(
            projectName: project.name,
            targetName: t,
            reason:
                'Skipped because a dependency failed: ${project.dependencies.where((d) => failedProjects.contains(d)).join(', ')}',
          ),
        );
      }
      return results;
    }

    var projectFailed = false;
    for (final pipelineTarget in pipeline) {
      if (projectFailed) {
        results.add(
          TaskResult.skipped(
            projectName: project.name,
            targetName: pipelineTarget,
            reason: 'Skipped because previous pipeline target failed',
          ),
        );
        continue;
      }

      // Handle ^ transitive targets
      if (TaskPipeline.isTransitive(pipelineTarget)) {
        final stripped = TaskPipeline.stripPrefix(pipelineTarget);
        for (final depName in project.dependencies) {
          if (_completedTransitive.contains('$depName:$stripped')) continue;
          final depProject = allProjects
              .where((p) => p.name == depName)
              .firstOrNull;
          if (depProject == null) continue;

          final depExec = _resolveExecutor(depProject, stripped);
          if (depExec.isEmpty) continue;

          final depResult = await executor.execute(
            project: depProject,
            targetName: stripped,
            executor: depExec,
            configurationName: configurationName,
          );
          results.add(depResult);
          _completedTransitive.add('$depName:$stripped');

          if (depResult.isFailure) {
            projectFailed = true;
            failedProjects.add(depProject.name);
          }
        }
        continue;
      }

      final execCommand = _resolveExecutor(project, pipelineTarget);
      if (execCommand.isEmpty) {
        results.add(
          TaskResult.skipped(
            projectName: project.name,
            targetName: pipelineTarget,
            reason: 'No executor configured for target "$pipelineTarget"',
          ),
        );
        continue;
      }

      // Check if the resolved target is continuous
      final resolvedTarget =
          project.targets[pipelineTarget] ?? config.targets[pipelineTarget];
      final isContinuous = resolvedTarget?.continuous ?? false;

      if (isContinuous && continuousManager != null) {
        final parts = execCommand.split(' ');
        final result = await continuousManager.start(
          projectName: project.name,
          targetName: pipelineTarget,
          executable: parts.first,
          arguments: parts.skip(1).toList(),
          workingDirectory: project.path,
        );
        results.add(result);
        // Continuous tasks don't block the pipeline or mark failures
        continue;
      }

      final result = await executor.execute(
        project: project,
        targetName: pipelineTarget,
        executor: execCommand,
        configurationName: configurationName,
      );
      results.add(result);

      if (result.isFailure) {
        projectFailed = true;
        failedProjects.add(project.name);
      }
    }

    return results;
  }

  /// Execute a batch of projects sharing the same executor as a single process.
  ///
  /// Runs the executor once from the workspace root with all project paths
  /// as arguments. Maps the single result back to individual [TaskResult]s.
  Future<List<TaskResult>> _runBatch(
    BatchGroup group,
    String targetName,
    TaskExecutor executor,
  ) async {
    final start = DateTime.now();
    final projectPaths = group.projects.map((p) => p.path).toList();

    // Run executor once with all project paths
    final parts = group.executor.split(' ');
    final executable = parts.first;
    final arguments = [...parts.skip(1), ...projectPaths];

    final call = ProcessCall(
      executable: executable,
      arguments: arguments,
      workingDirectory: '.',
    );

    final processResult = await processRunner.run(call);
    final duration = DateTime.now().difference(start);
    final status = processResult.exitCode == 0
        ? TaskStatus.success
        : TaskStatus.failure;

    // Map single result to per-project results
    return group.projects
        .map(
          (project) => TaskResult(
            projectName: project.name,
            targetName: targetName,
            status: status,
            exitCode: processResult.exitCode,
            stdout: processResult.stdout,
            stderr: processResult.stderr,
            duration: duration,
          ),
        )
        .toList();
  }

  String _resolveExecutor(Project project, String targetName) {
    final projectTarget = project.targets[targetName];
    if (projectTarget != null) return projectTarget.executor;

    final wsTarget = config.targets[targetName];
    if (wsTarget == null) return '';
    var executor = wsTarget.executor;

    if (project.isFlutter) {
      executor = Workspace.routeFlutterExecutor(executor);
    }
    return executor;
  }
}
