import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import 'format_command.dart';
import 'run_command.dart';
import 'sync_command.dart';

/// `fx format:check` — Check formatting without modifying files.
///
/// Equivalent to `fx format --check`. Exits with code 1 if any files
/// would be changed.
class FormatCheckCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'format:check';

  @override
  String get description =>
      'Check formatting without modifying files (exits 1 if changes needed).';

  FormatCheckCommand({required this.formatter, required this.processRunner}) {
    argParser
      ..addOption(
        'projects',
        help: 'Comma-separated project names or glob patterns to check.',
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
    final projectsArg = argResults!['projects'] as String?;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    List<Project> packages;
    if (projectsArg != null && projectsArg.isNotEmpty) {
      final patterns = projectsArg.split(',').map((s) => s.trim()).toList();
      packages = workspace.projects
          .where((p) => FormatCommand.matchesAny(p.name, patterns))
          .toList();
    } else {
      packages = workspace.projects;
    }

    bool hasChanges = false;
    for (final project in packages) {
      formatter.writeln('Checking ${project.name}...');
      final result = await processRunner.run(
        ProcessCall(
          executable: 'dart',
          arguments: ['format', '--output=none', '--set-exit-if-changed', '.'],
          workingDirectory: project.path,
        ),
      );
      if (result.exitCode != 0) {
        hasChanges = true;
        formatter.writeln('  ${project.name}: formatting changes needed');
      }
      if (result.stderr.isNotEmpty) {
        formatter.writeln(result.stderr);
      }
    }

    if (hasChanges) {
      formatter.writeln('\nFormat check failed. Run `fx format` to fix.');
      throw const ProcessExit(1);
    }
    formatter.writeln('All files are properly formatted.');
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

/// `fx sync:check` — Check workspace consistency without modifying files.
///
/// Equivalent to `fx sync --check`. Exits with code 1 if any issues found.
class SyncCheckCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'sync:check';

  @override
  String get description =>
      'Check workspace consistency without modifying files (exits 1 if issues found).';

  SyncCheckCommand({required this.formatter}) {
    argParser.addOption(
      'workspace',
      help: 'Path to workspace root (for testing).',
      hide: true,
    );
  }

  @override
  Future<void> run() async {
    final workspacePath = argResults!['workspace'] as String?;
    final root =
        workspacePath ?? FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }

    final issues = await SyncCommand.checkWorkspace(root, formatter);

    if (issues > 0) {
      formatter.writeln('\n$issues issue(s) found. Run `fx sync` to fix.');
      throw const ProcessExit(1);
    }
    formatter.writeln('Workspace is in sync. All checks passed.');
  }
}
