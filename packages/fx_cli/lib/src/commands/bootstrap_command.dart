import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';
import 'run_command.dart';

/// `fx bootstrap` — Run `dart pub get` at the workspace root.
///
/// Leverages Dart pub workspace support so a single `dart pub get` at the
/// root resolves all dependencies for all workspace members together.
class BootstrapCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'bootstrap';

  @override
  String get description =>
      'Run `dart pub get` at the workspace root to install all dependencies.';

  BootstrapCommand({required this.formatter, required this.processRunner}) {
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

    formatter.writeln('Running dart pub get at ${workspace.rootPath}...');

    final result = await processRunner.run(
      ProcessCall(
        executable: 'dart',
        arguments: ['pub', 'get'],
        workingDirectory: workspace.rootPath,
      ),
    );

    if (result.exitCode != 0) {
      formatter.writeln('dart pub get failed: ${result.stderr}');
      throw const ProcessExit(1);
    }

    formatter.writeln(
      result.stdout.isNotEmpty ? result.stdout : 'Bootstrap complete.',
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
