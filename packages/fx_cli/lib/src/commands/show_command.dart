import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import '../output/output_formatter.dart';

/// `fx show` — Show project details.
class ShowCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'show';

  @override
  String get description =>
      'Show detailed information about a project or list all projects.\n\n'
      'Usage: fx show project <name>\n'
      '       fx show projects';

  ShowCommand({required this.formatter}) {
    argParser
      ..addFlag('json', help: 'Output in JSON format.', negatable: false)
      ..addOption(
        'withTarget',
        help: 'Only show projects that have a specific target defined.',
      )
      ..addOption(
        'type',
        help: 'Filter by project type.',
        allowed: ['app', 'package', 'plugin'],
      )
      ..addFlag(
        'affected',
        help: 'Only show projects affected by git changes.',
        negatable: false,
      )
      ..addOption(
        'sep',
        help: 'Separator for list output (e.g., comma, newline).',
        defaultsTo: '\n',
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
    final workspacePath = argResults!['workspace'] as String?;
    final asJson = argResults!['json'] as bool;

    if (rest.isEmpty) {
      throw UsageException(
        'Usage: fx show project <name> | fx show projects',
        usage,
      );
    }

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    final subcommand = rest[0];

    switch (subcommand) {
      case 'projects':
        _showProjects(workspace, asJson);
      case 'project':
        if (rest.length < 2) {
          throw UsageException('Usage: fx show project <name>', usage);
        }
        _showProject(workspace, rest[1], asJson);
      default:
        // Treat as project name directly: fx show <name>
        _showProject(workspace, subcommand, asJson);
    }
  }

  List<Project> _applyFilters(Workspace workspace) {
    final withTarget = argResults!['withTarget'] as String?;
    final typeFilter = argResults!['type'] as String?;

    var projects = workspace.projects;

    if (withTarget != null) {
      projects = projects.where((p) {
        // Check project-level targets or workspace-level defaults/targets
        final projectTarget = p.targets[withTarget];
        final resolved = workspace.config.resolveTarget(
          withTarget,
          projectTarget: projectTarget,
        );
        return resolved != null;
      }).toList();
    }

    if (typeFilter != null) {
      projects = projects.where((p) => p.type.toJson() == typeFilter).toList();
    }

    return projects;
  }

  void _showProjects(Workspace workspace, bool asJson) {
    final projects = _applyFilters(workspace);
    final sep = argResults!['sep'] as String;

    if (asJson) {
      final data = projects.map((p) => _projectDetail(p, workspace)).toList();
      formatter.writeln(const JsonEncoder.withIndent('  ').convert(data));
    } else {
      final names = projects.map((p) => '${p.name} (${p.type.toJson()})');
      if (sep == '\n') {
        for (final name in names) {
          formatter.writeln(name);
        }
      } else {
        formatter.writeln(names.join(sep));
      }
    }
  }

  void _showProject(Workspace workspace, String name, bool asJson) {
    final project = workspace.projectByName(name);
    if (project == null) {
      throw UsageException('Project "$name" not found.', usage);
    }

    final dependents = <String>[];
    for (final p in workspace.projects) {
      if (p.dependencies.contains(name)) dependents.add(p.name);
    }

    if (asJson) {
      final data = _projectDetail(project, workspace, dependents: dependents);
      formatter.writeln(const JsonEncoder.withIndent('  ').convert(data));
    } else {
      formatter.writeln('Project: ${project.name}');
      formatter.writeln('Type: ${project.type.toJson()}');
      formatter.writeln('Path: ${project.path}');
      if (project.tags.isNotEmpty) {
        formatter.writeln('Tags: ${project.tags.join(', ')}');
      }
      if (project.dependencies.isNotEmpty) {
        formatter.writeln('Dependencies: ${project.dependencies.join(', ')}');
      }
      if (dependents.isNotEmpty) {
        formatter.writeln('Dependents: ${dependents.join(', ')}');
      }
      if (project.targets.isNotEmpty) {
        formatter.writeln('Targets:');
        for (final entry in project.targets.entries) {
          final t = entry.value;
          formatter.writeln('  ${t.name}: ${t.executor}');
          if (t.dependsOn.isNotEmpty) {
            formatter.writeln('    dependsOn: ${t.dependsOn.join(', ')}');
          }
          if (t.inputs.isNotEmpty) {
            formatter.writeln('    inputs: ${t.inputs.join(', ')}');
          }
        }
      }
    }
  }

  Map<String, dynamic> _projectDetail(
    Project project,
    Workspace workspace, {
    List<String>? dependents,
  }) {
    dependents ??= [
      for (final p in workspace.projects)
        if (p.dependencies.contains(project.name)) p.name,
    ];

    return {
      'name': project.name,
      'type': project.type.toJson(),
      'path': project.path,
      'tags': project.tags,
      'dependencies': project.dependencies,
      'dependents': dependents,
      'targets': {
        for (final entry in project.targets.entries)
          entry.key: {
            'executor': entry.value.executor,
            if (entry.value.dependsOn.isNotEmpty)
              'dependsOn': entry.value.dependsOn,
            if (entry.value.inputs.isNotEmpty) 'inputs': entry.value.inputs,
          },
      },
    };
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
