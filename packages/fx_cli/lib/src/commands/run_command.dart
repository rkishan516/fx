import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_cache/fx_cache.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;

import '../output/output_formatter.dart';

/// `fx run <project> <target>` — Run a target on a single project.
class RunCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;
  final String? cacheDir;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Run a target on a specific project.\n\n'
      'Usage: fx run <project> <target>';

  RunCommand({
    required this.formatter,
    required this.processRunner,
    this.cacheDir,
  }) {
    argParser
      ..addFlag(
        'skip-cache',
        help: 'Bypass the computation cache.',
        negatable: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show full command output.',
        negatable: false,
      )
      ..addFlag(
        'exclude-task-dependencies',
        help: 'Skip running dependent tasks first (dependsOn).',
        negatable: false,
      )
      ..addOption(
        'configuration',
        abbr: 'c',
        help: 'Named configuration to use (e.g., production).',
      )
      ..addOption(
        'output-style',
        help: 'Output style.',
        allowed: ['stream', 'static', 'tui'],
        defaultsTo: 'stream',
      )
      ..addFlag(
        'graph',
        help: 'Preview the task execution plan without running.',
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
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException(
        'Usage: fx run <project> <target>  or  fx run :<script>',
        usage,
      );
    }

    final workspacePath = argResults!['workspace'] as String?;
    final skipCacheFlag = argResults!['skip-cache'] as bool;

    // Support root-level scripts: fx run :script-name
    if (rest[0].startsWith(':')) {
      await _runRootScript(rest[0].substring(1), workspacePath);
      return;
    }

    if (rest.length < 2) {
      throw UsageException(
        'Usage: fx run <project> <target>  or  fx run :<script>',
        usage,
      );
    }

    final projectName = rest[0];
    final targetName = rest[1];
    final configurationName = argResults!['configuration'] as String?;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    final project = workspace.projectByName(projectName);
    if (project == null) {
      throw UsageException(
        'Project "$projectName" not found in workspace.',
        usage,
      );
    }

    // --graph: preview what would run without executing
    final graphPreview = argResults!['graph'] as bool;
    if (graphPreview) {
      final pipeline = TaskPipeline.resolve(targetName, workspace.config);
      formatter.writeln('Task Execution Plan for ${project.name}:$targetName:');
      for (final t in pipeline) {
        formatter.writeln('  ${project.name}:$t');
      }
      return;
    }

    final effectiveCacheDir =
        cacheDir ??
        p.join(workspace.rootPath, workspace.config.cacheConfig.directory);
    final skipCache = skipCacheFlag || workspace.config.skipCache;
    final localStore = LocalCacheStore(
      cacheDir: effectiveCacheDir,
      maxSizeMB: workspace.config.cacheConfig.maxSize,
    );
    final cacheManager = skipCache
        ? null
        : CacheManager(localStore: localStore);

    // Compute cache key if caching enabled and target allows caching
    String? inputHash;
    final resolvedTarget = workspace.config.resolveTarget(
      targetName,
      projectTarget: project.targets[targetName],
    );
    final targetCacheEnabled = resolvedTarget?.cache ?? true;
    if (cacheManager != null && targetCacheEnabled) {
      final inputPatterns = resolvedTarget?.inputs ?? [];
      final resolved = PathTokens.resolveAll(
        inputPatterns,
        projectRoot: project.path,
        workspaceRoot: workspace.rootPath,
        projectName: project.name,
      );
      inputHash = await Hasher.hashInputs(
        projectPath: project.path,
        targetName: targetName,
        executor: workspace.resolveExecutor(project, targetName),
        inputPatterns: resolved,
      );

      final cached = await cacheManager.get(inputHash);
      if (cached != null) {
        formatter.writeln(
          '[cached] ${project.name}:$targetName (${cached.duration.inMilliseconds}ms)',
        );
        // Replay captured output
        if (cached.stdout.isNotEmpty) formatter.write(cached.stdout);
        if (cached.stderr.isNotEmpty) formatter.write(cached.stderr);
        // Restore output artifacts (build outputs, generated files)
        if (cached.outputArtifacts.isNotEmpty) {
          final restored = await OutputCollector.restore(
            projectPath: project.path,
            artifacts: cached.outputArtifacts,
          );
          if (restored > 0) {
            formatter.writeln('[cache] Restored $restored output file(s)');
          }
        }
        return;
      }
    }

    final runner = TaskRunner(
      processRunner: processRunner,
      config: workspace.config,
      concurrency: 1,
    );

    final excludeTaskDeps = argResults!['exclude-task-dependencies'] as bool;
    final results = await runner.run(
      projects: [project],
      targetName: targetName,
      configurationName: configurationName,
      excludeTaskDependencies: excludeTaskDeps,
    );

    _printSummary(results, targetName);

    // Store in cache if successful
    if (cacheManager != null && inputHash != null) {
      final result = results.firstWhere(
        (r) => !r.isSkipped,
        orElse: () => results.first,
      );
      if (result.isSuccess) {
        // Collect output artifacts if target defines outputs
        final outputPatterns = resolvedTarget?.outputs ?? [];
        Map<String, String> outputArtifacts = const {};
        if (outputPatterns.isNotEmpty) {
          final resolvedOutputs = PathTokens.resolveAll(
            outputPatterns,
            projectRoot: project.path,
            workspaceRoot: workspace.rootPath,
            projectName: project.name,
          );
          outputArtifacts = await OutputCollector.collect(
            projectPath: project.path,
            outputPatterns: resolvedOutputs,
          );
        }
        // captureStderr: when false (default), cache stderr; when true,
        // store stderr separately so it can be replayed independently.
        final stderrToCache = workspace.config.captureStderr
            ? result.stderr
            : '';
        await cacheManager.put(
          inputHash,
          CacheEntry(
            projectName: project.name,
            targetName: targetName,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: stderrToCache,
            duration: result.duration,
            inputHash: inputHash,
            outputArtifacts: outputArtifacts,
          ),
        );
      }
    }

    final hasFailed = results.any((r) => r.isFailure);
    if (hasFailed) throw const ProcessExit(1);
  }

  void _printSummary(List<TaskResult> results, String targetName) {
    formatter.writeln('\nResults for $targetName:');
    for (final r in results) {
      final status = r.isSuccess
          ? 'success'
          : r.isSkipped
          ? 'skipped'
          : 'FAILED';
      final dur = ' (${r.duration.inMilliseconds}ms)';
      formatter.writeln('  ${r.projectName.padRight(30)} $status$dur');
    }
  }

  Future<void> _runRootScript(String scriptName, String? workspacePath) async {
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );
    final command = workspace.config.scripts[scriptName];
    if (command == null) {
      throw UsageException(
        'Root script "$scriptName" not found. '
        'Available scripts: ${workspace.config.scripts.keys.join(', ')}',
        usage,
      );
    }

    formatter.writeln('Running :$scriptName...');
    final parts = command.split(' ');
    final result = await processRunner.run(
      ProcessCall(
        executable: parts.first,
        arguments: parts.skip(1).toList(),
        workingDirectory: workspace.rootPath,
      ),
    );

    if (result.stdout.isNotEmpty) formatter.write(result.stdout);
    if (result.stderr.isNotEmpty) formatter.write(result.stderr);

    if (result.exitCode != 0) throw ProcessExit(result.exitCode);
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

/// Thrown by commands to signal a non-zero exit without exiting the process.
class ProcessExit implements Exception {
  final int exitCode;
  const ProcessExit(this.exitCode);
}
