import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import '../output/tui_formatter.dart';
import 'run_command.dart';

/// `fx run-many --target=<target>` — Run a target on multiple projects.
class RunManyCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'run-many';

  @override
  String get description =>
      'Run a target across multiple (or all) projects in topological order.';

  RunManyCommand({required this.formatter, required this.processRunner}) {
    argParser
      ..addOption('target', abbr: 't', help: 'Target to run.')
      ..addOption(
        'targets',
        help: 'Comma-separated list of targets to run (e.g., build,test).',
      )
      ..addOption(
        'projects',
        help:
            'Comma-separated project names or glob patterns (e.g., pkg-*, *_core).',
      )
      ..addOption(
        'exclude',
        help: 'Comma-separated project names or glob patterns to exclude.',
      )
      ..addOption(
        'concurrency',
        abbr: 'c',
        help: 'Max parallel executions.',
        defaultsTo: null,
      )
      ..addFlag(
        'skip-cache',
        help: 'Bypass the computation cache.',
        negatable: false,
      )
      ..addFlag(
        'bail',
        help: 'Stop execution after first task failure.',
        negatable: false,
      )
      ..addOption(
        'output-style',
        help: 'Output style.',
        allowed: ['stream', 'static', 'tui'],
        defaultsTo: 'stream',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show full command output.',
        negatable: false,
      )
      ..addOption(
        'workers',
        help: 'Total number of workers for distributed execution (CI matrix).',
      )
      ..addOption(
        'worker-index',
        help: 'This worker\'s index (0-based) for distributed execution.',
      )
      ..addOption(
        'configuration',
        help: 'Named configuration to use (e.g., production).',
      )
      ..addFlag(
        'exclude-task-dependencies',
        help: 'Skip running dependent tasks first (dependsOn).',
        negatable: false,
      )
      ..addFlag(
        'graph',
        help: 'Preview the task execution graph without running.',
        negatable: false,
      )
      ..addOption(
        'workspace',
        help: 'Path to workspace root (for testing).',
        hide: true,
      );
  }

  @override
  Future<void> run() async {
    final targetArg = argResults!['target'] as String?;
    final targetsArg = argResults!['targets'] as String?;

    // Resolve target list: --targets takes precedence, then --target
    final List<String> targetNames;
    if (targetsArg != null && targetsArg.isNotEmpty) {
      targetNames = targetsArg.split(',').map((s) => s.trim()).toList();
    } else if (targetArg != null && targetArg.isNotEmpty) {
      targetNames = [targetArg];
    } else {
      throw UsageException(
        'Either --target or --targets must be specified.',
        usage,
      );
    }

    final projectsArg = argResults!['projects'] as String?;
    final excludeArg = argResults!['exclude'] as String?;
    final concurrencyArg = argResults!['concurrency'] as String?;
    final workspacePath = argResults!['workspace'] as String?;
    final bail = argResults!['bail'] as bool;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    // Select projects to run on (supports glob patterns)
    List<Project> selected;
    if (projectsArg != null && projectsArg.isNotEmpty) {
      final patterns = projectsArg.split(',').map((s) => s.trim()).toList();
      selected = workspace.projects
          .where((p) => _matchesAny(p.name, patterns))
          .toList();
    } else {
      selected = workspace.projects;
    }

    // Apply exclusions
    if (excludeArg != null && excludeArg.isNotEmpty) {
      final excludePatterns = excludeArg
          .split(',')
          .map((s) => s.trim())
          .toList();
      selected = selected
          .where((p) => !_matchesAny(p.name, excludePatterns))
          .toList();
    }

    // Apply distributed partitioning if requested
    final workersArg = argResults!['workers'] as String?;
    final workerIndexArg = argResults!['worker-index'] as String?;

    if (workersArg != null && workerIndexArg != null) {
      final totalWorkers = int.tryParse(workersArg);
      final workerIndex = int.tryParse(workerIndexArg);
      if (totalWorkers == null || totalWorkers < 1) {
        throw UsageException('--workers must be a positive integer.', usage);
      }
      if (workerIndex == null ||
          workerIndex < 0 ||
          workerIndex >= totalWorkers) {
        throw UsageException(
          '--worker-index must be between 0 and ${totalWorkers - 1}.',
          usage,
        );
      }
      final config = DistributedConfig(
        totalWorkers: totalWorkers,
        workerIndex: workerIndex,
      );
      selected = TaskPartitioner.getPartition(
        selected,
        config.totalWorkers,
        config.workerIndex,
      );
      formatter.writeln(
        'Distributed mode: worker ${config.workerIndex + 1}/${config.totalWorkers}, '
        '${selected.length} projects assigned.',
      );
    }

    if (selected.isEmpty) {
      formatter.writeln('No projects to run on.');
      return;
    }

    // Sort topologically
    final graph = ProjectGraph.build(workspace.projects);
    final sorted = TopologicalSort.sort(selected, graph);

    // --graph: preview what would run without executing
    final graphPreview = argResults!['graph'] as bool;
    if (graphPreview) {
      _printGraphPreview(sorted, targetNames);
      return;
    }

    final concurrency = concurrencyArg != null
        ? int.tryParse(concurrencyArg) ?? Platform.numberOfProcessors
        : workspace.config.parallel ?? Platform.numberOfProcessors;

    final runner = TaskRunner(
      processRunner: processRunner,
      config: workspace.config,
      concurrency: concurrency,
    );

    final outputStyle = argResults!['output-style'] as String?;
    final useTui = outputStyle == 'tui';
    final tui = useTui ? TuiFormatter(formatter.sink) : null;

    final allResults = <TaskResult>[];
    final failedProjects = <String>{};

    for (final tn in targetNames) {
      final configurationName = argResults!['configuration'] as String?;
      final excludeTaskDeps = argResults!['exclude-task-dependencies'] as bool;
      final results = await runner.run(
        projects: sorted,
        targetName: tn,
        failedProjects: failedProjects,
        bail: bail,
        configurationName: configurationName,
        excludeTaskDependencies: excludeTaskDeps,
      );
      allResults.addAll(results);
      if (tui != null) {
        for (final r in results) {
          tui.writeTaskResult(r);
        }
        tui.writeSummary(results, tn);
      } else {
        _printSummary(results, tn);
      }

      if (bail && results.any((r) => r.isFailure)) break;
    }

    final hasFailed = allResults.any((r) => r.isFailure);
    if (hasFailed) throw const ProcessExit(1);
  }

  void _printGraphPreview(List<Project> projects, List<String> targets) {
    formatter.writeln('Task Execution Plan:');
    formatter.writeln('');
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      for (final t in targets) {
        formatter.writeln('  ${p.name}:$t');
      }
    }
    formatter.writeln('');
    formatter.writeln(
      '${projects.length} project(s) x ${targets.length} target(s) = '
      '${projects.length * targets.length} task(s)',
    );
  }

  void _printSummary(List<TaskResult> results, String targetName) {
    formatter.writeln('\nResults for $targetName:');
    for (final r in results) {
      final status = r.isSuccess
          ? 'success'
          : r.isSkipped
          ? 'skipped'
          : 'FAILED';
      formatter.writeln(
        '  ${r.projectName.padRight(30)} $status (${r.duration.inMilliseconds}ms)',
      );
    }
  }

  /// Returns true if [name] matches any of the [patterns].
  /// Patterns support `*` as a wildcard (e.g., `fx_*`, `*_core`).
  static bool _matchesAny(String name, List<String> patterns) {
    for (final pattern in patterns) {
      if (!pattern.contains('*')) {
        if (name == pattern) return true;
      } else {
        final regex = RegExp(
          '^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$',
        );
        if (regex.hasMatch(name)) return true;
      }
    }
    return false;
  }

  String _findWorkspaceRoot() {
    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }
    return root;
  }
}
