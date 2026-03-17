import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import '../output/tui_formatter.dart';
import 'run_command.dart';

/// `fx affected` — Run a target on projects affected by git changes.
class AffectedCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'affected';

  @override
  String get description =>
      'Run a target on projects affected by changes since a git ref.';

  AffectedCommand({required this.formatter, required this.processRunner}) {
    argParser
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target to run (optional — lists if omitted).',
      )
      ..addOption(
        'base',
        help: 'Base git ref for comparison (default from workspace config).',
      )
      ..addOption(
        'head',
        help: 'Head git ref for comparison.',
        defaultsTo: 'HEAD',
      )
      ..addOption(
        'files',
        help: 'Comma-separated list of changed files (overrides git diff).',
      )
      ..addOption(
        'exclude',
        help: 'Comma-separated project names or globs to exclude.',
      )
      ..addOption('parallel', help: 'Max parallel task executions.')
      ..addOption(
        'output-style',
        help: 'Output style.',
        allowed: ['stream', 'static', 'tui'],
        defaultsTo: 'stream',
      )
      ..addFlag(
        'bail',
        help: 'Stop execution after first task failure.',
        negatable: false,
      )
      ..addFlag(
        'uncommitted',
        help: 'Include uncommitted changes.',
        negatable: false,
      )
      ..addFlag('untracked', help: 'Include untracked files.', negatable: false)
      ..addFlag(
        'graph',
        help: 'Show affected project graph instead of running.',
        negatable: false,
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
        'verbose',
        abbr: 'v',
        help: 'Show full command output.',
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
    final targetName = argResults!['target'] as String?;
    final head = argResults!['head'] as String;
    final filesArg = argResults!['files'] as String?;
    final excludeArg = argResults!['exclude'] as String?;
    final workspacePath = argResults!['workspace'] as String?;
    final bail = argResults!['bail'] as bool;
    final showGraph = argResults!['graph'] as bool;
    final uncommitted = argResults!['uncommitted'] as bool;
    final untracked = argResults!['untracked'] as bool;
    final parallelArg = argResults!['parallel'] as String?;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );
    // Use --base flag or fall back to workspace config defaultBase
    final base = argResults!['base'] as String? ?? workspace.config.defaultBase;
    final graph = ProjectGraph.build(workspace.projects);

    // Get changed files — either from --files or git
    List<String> changedFiles;
    if (filesArg != null && filesArg.isNotEmpty) {
      changedFiles = filesArg
          .split(',')
          .map((f) => '${workspace.rootPath}/${f.trim()}')
          .toList();
    } else {
      changedFiles = await _getChangedFiles(
        workspace.rootPath,
        base,
        head,
        includeUncommitted: uncommitted,
        includeUntracked: untracked,
      );
    }

    // Compute affected projects
    var affected = AffectedAnalyzer.computeAffected(
      changedFiles: changedFiles,
      projects: workspace.projects,
      graph: graph,
      workspaceRoot: workspace.rootPath,
      lockfileAffectsAll: workspace.config.lockfileAffectsAll,
    );

    // Apply exclusions
    if (excludeArg != null && excludeArg.isNotEmpty) {
      final excludePatterns = excludeArg
          .split(',')
          .map((s) => s.trim())
          .toList();
      affected = affected
          .where((p) => !_matchesAny(p.name, excludePatterns))
          .toList();
    }

    if (affected.isEmpty) {
      formatter.writeln('No affected projects.');
      return;
    }

    // Show affected graph
    if (showGraph) {
      formatter.writeln('Affected project graph:');
      for (final p in affected) {
        final deps = p.dependencies
            .where((d) => affected.any((a) => a.name == d))
            .toList();
        if (deps.isEmpty) {
          formatter.writeln('  ${p.name}');
        } else {
          formatter.writeln('  ${p.name}  ← ${deps.join(', ')}');
        }
      }
      return;
    }

    // If no target given, just list affected projects
    if (targetName == null) {
      formatter.writeln('Affected projects:');
      for (final p in affected) {
        formatter.writeln('  ${p.name}');
      }
      return;
    }

    // Sort affected projects topologically and run the target
    final sorted = TopologicalSort.sort(affected, graph);

    final concurrency = parallelArg != null
        ? int.tryParse(parallelArg) ?? Platform.numberOfProcessors
        : workspace.config.parallel ?? Platform.numberOfProcessors;

    final runner = TaskRunner(
      processRunner: processRunner,
      config: workspace.config,
      concurrency: concurrency,
    );

    final configurationName = argResults!['configuration'] as String?;
    final excludeTaskDeps = argResults!['exclude-task-dependencies'] as bool;
    final results = await runner.run(
      projects: sorted,
      targetName: targetName,
      bail: bail,
      configurationName: configurationName,
      excludeTaskDependencies: excludeTaskDeps,
    );

    final outputStyle = argResults!['output-style'] as String?;
    if (outputStyle == 'tui') {
      final tui = TuiFormatter(formatter.sink);
      for (final r in results) {
        tui.writeTaskResult(r);
      }
      tui.writeSummary(results, targetName);
    } else {
      _printSummary(results, targetName);
    }

    final hasFailed = results.any((r) => r.isFailure);
    if (hasFailed) throw const ProcessExit(1);
  }

  /// Returns list of changed file paths by running git diff.
  Future<List<String>> _getChangedFiles(
    String workspaceRoot,
    String base,
    String head, {
    bool includeUncommitted = false,
    bool includeUntracked = false,
  }) async {
    final changedLines = <String>[];

    // Changes between base and head
    final diffResult = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['diff', '--name-only', '$base...$head'],
        workingDirectory: workspaceRoot,
      ),
    );
    changedLines.addAll(
      diffResult.stdout
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => '$workspaceRoot/$l'),
    );

    // Uncommitted changes (staged + unstaged)
    if (includeUncommitted) {
      final uncommittedResult = await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: ['diff', '--name-only', 'HEAD'],
          workingDirectory: workspaceRoot,
        ),
      );
      changedLines.addAll(
        uncommittedResult.stdout
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .map((l) => '$workspaceRoot/$l'),
      );
    }

    // Untracked files
    if (includeUntracked) {
      final untrackedResult = await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: ['ls-files', '--others', '--exclude-standard'],
          workingDirectory: workspaceRoot,
        ),
      );
      changedLines.addAll(
        untrackedResult.stdout
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .map((l) => '$workspaceRoot/$l'),
      );
    }

    return changedLines.toSet().toList(); // deduplicate
  }

  void _printSummary(List<TaskResult> results, String targetName) {
    formatter.writeln('\nResults for $targetName (affected):');
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
