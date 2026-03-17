import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';

import '../output/output_formatter.dart';

/// `fx list` — Lists all projects in the workspace.
class ListCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'list';

  @override
  String get description => 'List all projects in the workspace.';

  ListCommand({required this.formatter}) {
    argParser
      ..addFlag(
        'json',
        help: 'Output in JSON format.',
        negatable: false,
        defaultsTo: false,
      )
      ..addOption(
        'type',
        help: 'Filter by project type.',
        allowed: ['app', 'package', 'plugin'],
      )
      ..addFlag(
        'affected',
        help: 'Only list projects affected by git changes.',
        negatable: false,
      )
      ..addOption(
        'projects',
        help: 'Comma-separated project names or glob patterns to list.',
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
    final typeFilter = argResults!['type'] as String?;
    final projectsArg = argResults!['projects'] as String?;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );
    final useJson = argResults!['json'] as bool;

    var projects = workspace.projects;

    if (typeFilter != null) {
      projects = projects.where((p) => p.type.toJson() == typeFilter).toList();
    }

    if (projectsArg != null && projectsArg.isNotEmpty) {
      final patterns = projectsArg.split(',').map((s) => s.trim()).toList();
      projects = projects.where((p) => _matchesAny(p.name, patterns)).toList();
    }

    if (useJson) {
      formatter.writeProjectJson(projects);
    } else {
      formatter.writeProjectTable(projects);
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
