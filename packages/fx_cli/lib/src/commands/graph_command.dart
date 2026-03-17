import 'dart:io';

import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import 'graph_web_server.dart';

/// `fx graph` — Outputs the project dependency graph.
class GraphCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'graph';

  @override
  String get description => 'Visualize the project dependency graph.';

  GraphCommand({required this.formatter, ProcessRunner? processRunner})
    : processRunner = processRunner ?? const SystemProcessRunner() {
    argParser
      ..addOption(
        'format',
        abbr: 'f',
        help: 'Output format: text, json, dot',
        allowed: ['text', 'json', 'dot'],
        defaultsTo: 'text',
      )
      ..addFlag(
        'web',
        help: 'Open interactive graph visualization in browser.',
        negatable: false,
      )
      ..addOption('port', help: 'Port for the web server.', defaultsTo: '4211')
      ..addFlag(
        'tasks',
        help: 'Show task execution graph (target dependencies).',
        negatable: false,
      )
      ..addOption(
        'focus',
        help: 'Focus on a specific project and its dependencies/dependents.',
      )
      ..addOption('file', help: 'Output graph to a file instead of stdout.')
      ..addFlag(
        'affected',
        help: 'Only show projects affected by changes since base.',
        negatable: false,
      )
      ..addFlag(
        'groupByFolder',
        help: 'Group projects by their parent directory.',
        negatable: false,
      )
      ..addFlag(
        'detect-implicit',
        help: 'Detect undeclared dependencies via import analysis.',
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
    final workspacePath = argResults!['workspace'] as String?;
    final format = argResults!['format'] as String;
    final web = argResults!['web'] as bool;
    final port = int.tryParse(argResults!['port'] as String) ?? 4211;

    final showTasks = argResults!['tasks'] as bool;
    final focus = argResults!['focus'] as String?;
    final outputFile = argResults!['file'] as String?;
    final showAffected = argResults!['affected'] as bool;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    if (showTasks) {
      await _printTaskGraph(workspace, format: format, outputFile: outputFile);
      return;
    }

    final detectImplicit = argResults!['detect-implicit'] as bool;

    ProjectGraph graph;
    if (detectImplicit || workspace.config.dynamicDependencies) {
      final implicitDeps = await ImportAnalyzer.detectAllImplicit(
        workspace.projects,
      );
      graph = ProjectGraph.buildWithImplicit(workspace.projects, implicitDeps);

      if (implicitDeps.isNotEmpty) {
        formatter.writeln('Implicit dependencies detected:');
        for (final entry in implicitDeps.entries) {
          for (final dep in entry.value) {
            formatter.writeln(
              '  ${entry.key} -> $dep (implicit, not in pubspec.yaml)',
            );
          }
        }
        formatter.writeln('');
      }
    } else {
      graph = ProjectGraph.build(workspace.projects);
    }

    // Filter to affected projects if requested
    var projects = workspace.projects;
    if (showAffected) {
      final changedFiles = await _getChangedFiles(workspace.rootPath);
      projects = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: workspace.projects,
        graph: graph,
        workspaceRoot: workspace.rootPath,
        lockfileAffectsAll: workspace.config.lockfileAffectsAll,
      );
      if (projects.isEmpty) {
        formatter.writeln('No affected projects.');
        return;
      }
    }

    // Focus on a specific project and its neighborhood
    if (focus != null) {
      final focusProject = workspace.projectByName(focus);
      if (focusProject == null) {
        throw UsageException('Project "$focus" not found.', usage);
      }
      final neighborhood = <Project>{focusProject};
      // Add direct dependencies
      for (final depName in focusProject.dependencies) {
        final dep = workspace.projectByName(depName);
        if (dep != null) neighborhood.add(dep);
      }
      // Add direct dependents
      for (final p in workspace.projects) {
        if (p.dependencies.contains(focus)) neighborhood.add(p);
      }
      projects = projects
          .where((p) => neighborhood.any((n) => n.name == p.name))
          .toList();
    }

    if (web) {
      final server = await GraphWebServer(
        workspace: workspace,
        graph: graph,
      ).serve(port: port);

      formatter.writeln(
        'Graph visualization running at http://localhost:${server.port}',
      );
      formatter.writeln('Press Ctrl+C to stop.');

      // Keep running until interrupted
      await ProcessSignal.sigint.watch().first;
      await server.close();
      return;
    }

    // Use a separate formatter for file output if requested
    final buffer = outputFile != null ? StringBuffer() : null;
    final target = buffer != null ? OutputFormatter(buffer) : formatter;

    final groupByFolder = argResults!['groupByFolder'] as bool;

    if (groupByFolder) {
      final groups = _groupByFolder(projects, workspace.rootPath);
      switch (format) {
        case 'json':
          _writeGroupedJson(target, graph, projects, groups);
        case 'dot':
          _writeGroupedDot(target, graph, projects, groups);
        default:
          _writeGroupedText(target, graph, projects, groups);
      }
    } else {
      switch (format) {
        case 'json':
          target.writeGraphJson(graph, projects);
        case 'dot':
          target.writeGraphDot(graph, projects);
        default:
          target.writeGraphText(graph, projects);
      }
    }

    if (outputFile != null && buffer != null) {
      await File(outputFile).writeAsString(buffer.toString());
      formatter.writeln('Graph written to $outputFile');
    }
  }

  Future<void> _printTaskGraph(
    Workspace workspace, {
    required String format,
    String? outputFile,
  }) async {
    final graph = TaskGraph.fromWorkspace(workspace);

    final String output;
    switch (format) {
      case 'json':
        output = GraphOutput.taskGraphToJson(graph);
      case 'dot':
        output = GraphOutput.taskGraphToDot(graph);
      default:
        // For text, fall back to workspace-level target display when
        // there are no project nodes (e.g. empty workspace with just config).
        if (graph.nodes.isEmpty) {
          output = _workspaceTargetText(workspace);
        } else {
          output = GraphOutput.taskGraphToText(graph);
        }
    }

    if (outputFile != null) {
      await File(outputFile).writeAsString(output);
      formatter.writeln('Task graph written to $outputFile');
    } else {
      formatter.writeln(output);
    }
  }

  /// Renders workspace-level targets as human-readable text when no project
  /// nodes exist in the task graph (e.g. the workspace has targets configured
  /// but no matching package directories on disk).
  String _workspaceTargetText(Workspace workspace) {
    final targets = workspace.config.targets;
    final defaults = workspace.config.targetDefaults;
    final allTargets = <String, List<String>>{};
    for (final entry in {...defaults, ...targets}.entries) {
      allTargets[entry.key] = entry.value.dependsOn;
    }
    if (allTargets.isEmpty) {
      return 'No targets defined in workspace configuration.';
    }
    final buf = StringBuffer();
    buf.writeln('Task Execution Graph:');
    buf.writeln('');

    // Topological sort for display order
    final visited = <String>{};
    final order = <String>[];
    void visit(String name) {
      if (visited.contains(name)) return;
      visited.add(name);
      for (final dep in allTargets[name] ?? <String>[]) {
        visit(dep.startsWith('^') ? dep.substring(1) : dep);
      }
      order.add(name);
    }

    for (final name in allTargets.keys) {
      visit(name);
    }
    for (final name in order) {
      final deps = allTargets[name] ?? [];
      if (deps.isEmpty) {
        buf.writeln('  $name');
      } else {
        buf.writeln('  $name  ← depends on: ${deps.join(', ')}');
      }
    }
    buf.writeln('');
    buf.writeln('Execution order (left to right): ${order.join(' → ')}');
    return buf.toString().trimRight();
  }

  Future<List<String>> _getChangedFiles(String workspaceRoot) async {
    final result = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['diff', '--name-only', 'main...HEAD'],
        workingDirectory: workspaceRoot,
      ),
    );
    return result.stdout
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => '$workspaceRoot/$l')
        .toList();
  }

  /// Groups projects by their parent directory relative to workspace root.
  Map<String, List<Project>> _groupByFolder(
    List<Project> projects,
    String workspaceRoot,
  ) {
    final groups = <String, List<Project>>{};
    for (final project in projects) {
      final rel = p.relative(project.path, from: workspaceRoot);
      final folder = p.dirname(rel);
      groups.putIfAbsent(folder, () => []).add(project);
    }
    return groups;
  }

  void _writeGroupedText(
    OutputFormatter target,
    ProjectGraph graph,
    List<Project> projects,
    Map<String, List<Project>> groups,
  ) {
    for (final entry in groups.entries) {
      target.writeln('${entry.key}/');
      for (final project in entry.value) {
        final deps = graph.dependenciesOf(project.name);
        final depStr = deps.isEmpty ? '' : ' → ${deps.join(', ')}';
        target.writeln('  ${project.name}$depStr');
      }
      target.writeln('');
    }
  }

  void _writeGroupedDot(
    OutputFormatter target,
    ProjectGraph graph,
    List<Project> projects,
    Map<String, List<Project>> groups,
  ) {
    target.writeln('digraph workspace {');
    target.writeln('  rankdir=LR;');

    for (final entry in groups.entries) {
      final clusterName = entry.key.replaceAll('/', '_');
      target.writeln('  subgraph cluster_$clusterName {');
      target.writeln('    label="${entry.key}";');
      for (final project in entry.value) {
        target.writeln('    "${project.name}";');
      }
      target.writeln('  }');
    }

    // Edges
    for (final project in projects) {
      for (final dep in graph.dependenciesOf(project.name)) {
        target.writeln('  "${project.name}" -> "$dep";');
      }
    }

    target.writeln('}');
  }

  void _writeGroupedJson(
    OutputFormatter target,
    ProjectGraph graph,
    List<Project> projects,
    Map<String, List<Project>> groups,
  ) {
    final groupList = groups.entries
        .map(
          (entry) => {
            'folder': entry.key,
            'projects': entry.value.map((p) => p.name).toList(),
          },
        )
        .toList();

    final nodes = <Map<String, dynamic>>[];
    for (final project in projects) {
      nodes.add({
        'name': project.name,
        'dependencies': graph.dependenciesOf(project.name).toList(),
      });
    }

    target.writeln(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'groups': groupList, 'nodes': nodes}),
    );
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
