import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import 'run_command.dart';

/// `fx analyze` — Run `dart analyze` across all workspace packages.
class AnalyzeCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'analyze';

  @override
  String get description => 'Run `dart analyze` across all workspace packages.';

  AnalyzeCommand({required this.formatter, required this.processRunner}) {
    argParser.addOption(
      'workspace',
      help: 'Path to workspace root (for testing).',
      hide: true,
    );
  }

  @override
  Future<void> run() async {
    final workspacePath = argResults!['workspace'] as String?;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    final packages = workspace.projects;
    int failCount = 0;

    for (final project in packages) {
      formatter.writeln('Analyzing ${project.name}...');

      final result = await processRunner.run(
        ProcessCall(
          executable: 'dart',
          arguments: ['analyze'],
          workingDirectory: project.path,
        ),
      );

      if (result.stdout.isNotEmpty) {
        formatter.writeln(result.stdout);
      }
      if (result.stderr.isNotEmpty) {
        formatter.writeln(result.stderr);
      }

      if (result.exitCode != 0) {
        failCount++;
      }
    }

    if (failCount > 0) {
      formatter.writeln('$failCount package(s) had analysis issues.');
      throw const ProcessExit(1);
    }
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
