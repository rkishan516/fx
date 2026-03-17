import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_runner/fx_runner.dart';
import '../output/output_formatter.dart';

/// `fx watch` — Watch for file changes and re-run a target.
class WatchCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'watch';

  @override
  String get description =>
      'Watch for file changes and re-run a target on affected projects.';

  WatchCommand({required this.formatter, required this.processRunner}) {
    argParser
      ..addOption('target', abbr: 't', help: 'Target to run.', mandatory: true)
      ..addOption(
        'projects',
        help: 'Comma-separated list of projects to watch.',
      )
      ..addFlag(
        'all',
        help: 'Watch all projects (default if --projects not set).',
        negatable: false,
      )
      ..addFlag(
        'includeDependentProjects',
        help: 'Also re-run on projects that depend on the changed project.',
        defaultsTo: true,
      )
      ..addFlag(
        'initialRun',
        help: 'Run the target once before watching for changes.',
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
    final targetName = argResults!['target'] as String;
    final projectsArg = argResults!['projects'] as String?;
    final workspacePath = argResults!['workspace'] as String?;
    final includeDependents = argResults!['includeDependentProjects'] as bool;
    final initialRun = argResults!['initialRun'] as bool;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );
    final graph = ProjectGraph.build(workspace.projects);

    // Select projects to watch
    List<Project> selected;
    if (projectsArg != null && projectsArg.isNotEmpty) {
      final names = projectsArg.split(',').map((s) => s.trim()).toSet();
      selected = workspace.projects
          .where((p) => names.contains(p.name))
          .toList();
    } else {
      selected = workspace.projects;
    }

    if (selected.isEmpty) {
      formatter.writeln('No projects to watch.');
      return;
    }

    // Run target once before watching if requested
    if (initialRun) {
      formatter.writeln(
        'Initial run of $targetName on ${selected.length} project(s)...\n',
      );
      final sorted = TopologicalSort.sort(selected, graph);
      final runner = TaskRunner(
        processRunner: processRunner,
        config: workspace.config,
      );
      final results = await runner.run(
        projects: sorted,
        targetName: targetName,
      );
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
      formatter.writeln('');
    }

    formatter.writeln('Watching ${selected.length} project(s) for changes...');
    formatter.writeln('Target: $targetName');
    formatter.writeln('Press Ctrl+C to stop.\n');

    // Set up file watchers for each project
    final watchers = <StreamSubscription<FileSystemEvent>>[];
    Timer? debounce;
    final changedProjects = <String>{};

    for (final project in selected) {
      final dir = Directory(project.path);
      if (!dir.existsSync()) continue;

      final sub = dir
          .watch(recursive: true)
          .where((event) => _isDartFile(event.path))
          .listen((event) {
            changedProjects.add(project.name);

            // Debounce: wait 500ms after last change before running
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 500), () async {
              final projectsToRun = changedProjects.toList();
              changedProjects.clear();

              // Also include transitive dependents if enabled
              final affected = <Project>{};
              for (final name in projectsToRun) {
                final proj = workspace.projectByName(name);
                if (proj != null) affected.add(proj);
                if (includeDependents) {
                  for (final p in workspace.projects) {
                    if (p.dependencies.contains(name)) affected.add(p);
                  }
                }
              }

              final sorted = TopologicalSort.sort(affected.toList(), graph);

              formatter.writeln(
                '\n--- Change detected in: ${projectsToRun.join(', ')} ---',
              );
              formatter.writeln(
                'Running $targetName on ${sorted.length} project(s)...\n',
              );

              final runner = TaskRunner(
                processRunner: processRunner,
                config: workspace.config,
              );

              final results = await runner.run(
                projects: sorted,
                targetName: targetName,
              );

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

              formatter.writeln('\nWaiting for changes...');
            });
          });

      watchers.add(sub);
    }

    // Keep running until interrupted
    await _waitForever();

    // Cleanup
    for (final w in watchers) {
      await w.cancel();
    }
  }

  bool _isDartFile(String path) {
    return path.endsWith('.dart') || path.endsWith('.yaml');
  }

  Future<void> _waitForever() {
    return Completer<void>().future;
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
