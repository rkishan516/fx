import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import 'affected_git.dart';

/// `fx list` — Lists all projects in the workspace.
class ListCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'list';

  @override
  String get description => 'List all projects in the workspace.';

  ListCommand({required this.formatter, required this.processRunner}) {
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
      ..addOption('base', help: 'Base git ref for affected filtering.')
      ..addOption(
        'head',
        help: 'Head git ref for affected filtering.',
        defaultsTo: 'HEAD',
      )
      ..addOption(
        'files',
        help: 'Comma-separated changed files for affected filtering.',
      )
      ..addFlag(
        'uncommitted',
        help: 'Include uncommitted changes in affected filtering.',
        negatable: false,
      )
      ..addFlag(
        'untracked',
        help: 'Include untracked files in affected filtering.',
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
    final useAffected = argResults!['affected'] as bool;
    final filesArg = argResults!['files'] as String?;
    final head = argResults!['head'] as String;
    final uncommitted = argResults!['uncommitted'] as bool;
    final untracked = argResults!['untracked'] as bool;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );
    final useJson = argResults!['json'] as bool;

    var projects = workspace.projects;

    if (useAffected) {
      final changedFiles = filesArg != null && filesArg.isNotEmpty
          ? AffectedGit.filesFromArg(workspace.rootPath, filesArg)
          : await AffectedGit(processRunner: processRunner).changedFiles(
              workspaceRoot: workspace.rootPath,
              base: AffectedGit.resolveBase(
                config: workspace.config,
                explicitBase: argResults!['base'] as String?,
              ),
              head: head,
              includeUncommitted: uncommitted,
              includeUntracked: untracked,
              fetchBase: AffectedGit.shouldFetchBase(),
            );

      projects = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: workspace.projects,
        graph: ProjectGraph.build(workspace.projects),
        workspaceRoot: workspace.rootPath,
        lockfileAffectsAll: workspace.config.lockfileAffectsAll,
      );
    }

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
