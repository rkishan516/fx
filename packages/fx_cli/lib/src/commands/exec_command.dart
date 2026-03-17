import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import 'run_command.dart';

/// `fx exec -- <command>` — Run an arbitrary command across all projects.
class ExecCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'exec';

  @override
  String get description =>
      'Run an arbitrary command across all projects.\n\n'
      'Usage: fx exec -- <command>';

  ExecCommand({required this.formatter, required this.processRunner}) {
    argParser
      ..addOption(
        'projects',
        help: 'Comma-separated project names or glob patterns to include.',
      )
      ..addOption(
        'exclude',
        help: 'Comma-separated project names or glob patterns to exclude.',
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
      throw UsageException('Usage: fx exec -- <command>', usage);
    }

    final workspacePath = argResults!['workspace'] as String?;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    // Select projects
    var selected = workspace.projects.toList();
    final projectsArg = argResults!['projects'] as String?;
    if (projectsArg != null && projectsArg.isNotEmpty) {
      final patterns = projectsArg.split(',').map((s) => s.trim()).toList();
      selected = selected.where((p) => _matchesAny(p.name, patterns)).toList();
    }
    final excludeArg = argResults!['exclude'] as String?;
    if (excludeArg != null && excludeArg.isNotEmpty) {
      final excludePatterns = excludeArg
          .split(',')
          .map((s) => s.trim())
          .toList();
      selected = selected
          .where((p) => !_matchesAny(p.name, excludePatterns))
          .toList();
    }

    if (selected.isEmpty) {
      formatter.writeln('No projects to run on.');
      return;
    }

    final command = rest.join(' ');
    formatter.writeln(
      'Running "$command" across ${selected.length} project(s):',
    );

    var hasFailure = false;
    for (final project in selected) {
      final parts = rest.toList();
      final result = await processRunner.run(
        ProcessCall(
          executable: parts.first,
          arguments: parts.skip(1).toList(),
          workingDirectory: project.path,
        ),
      );

      final status = result.exitCode == 0 ? 'success' : 'FAILED';
      formatter.writeln('  ${project.name.padRight(30)} $status');
      if (result.stdout.isNotEmpty) formatter.write(result.stdout);
      if (result.stderr.isNotEmpty) formatter.write(result.stderr);

      if (result.exitCode != 0) hasFailure = true;
    }

    if (hasFailure) throw const ProcessExit(1);
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
