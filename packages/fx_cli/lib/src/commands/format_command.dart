import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import 'run_command.dart';

/// `fx format` — Run `dart format .` across all workspace packages.
class FormatCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'format';

  @override
  String get description =>
      'Run `dart format .` across all workspace packages.';

  FormatCommand({required this.formatter, required this.processRunner}) {
    argParser
      ..addFlag(
        'check',
        help: 'Exit with non-zero if any files would be changed.',
        negatable: false,
      )
      ..addOption(
        'projects',
        help: 'Comma-separated project names or glob patterns to format.',
      )
      ..addOption(
        'workspace',
        help: 'Path to workspace root (for testing).',
        hide: true,
      );
  }

  @override
  Future<void> run() async {
    final check = argResults!['check'] as bool;
    final workspacePath = argResults!['workspace'] as String?;
    final projectsArg = argResults!['projects'] as String?;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    List<Project> packages;
    if (projectsArg != null && projectsArg.isNotEmpty) {
      final patterns = projectsArg.split(',').map((s) => s.trim()).toList();
      packages = workspace.projects
          .where((p) => matchesAny(p.name, patterns))
          .toList();
    } else {
      packages = workspace.projects;
    }
    bool hasChanges = false;

    for (final project in packages) {
      formatter.writeln('Formatting ${project.name}...');

      final result = await processRunner.run(
        ProcessCall(
          executable: 'dart',
          arguments: ['format', '.'],
          workingDirectory: project.path,
        ),
      );

      if (result.stdout.isNotEmpty) {
        formatter.writeln(result.stdout);
        if (result.stdout.contains('Changed')) {
          hasChanges = true;
        }
      }
      if (result.stderr.isNotEmpty) {
        formatter.writeln(result.stderr);
      }
    }

    if (check && hasChanges) {
      formatter.writeln('Format check failed: files would be changed.');
      throw const ProcessExit(1);
    }
  }

  static bool matchesAny(String name, List<String> patterns) {
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
