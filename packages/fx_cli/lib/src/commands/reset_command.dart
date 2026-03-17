import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;

import '../output/output_formatter.dart';

/// `fx reset` — Clear all caches and generated state.
class ResetCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'reset';

  @override
  String get description =>
      'Clear all caches, daemon state, and generated artifacts.';

  ResetCommand({required this.formatter}) {
    argParser
      ..addFlag(
        'only-cache',
        help: 'Only clear the computation cache.',
        negatable: false,
      )
      ..addFlag(
        'only-workspace-data',
        help: 'Only clear workspace state (daemon, graph cache).',
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
    final onlyCache = argResults!['only-cache'] as bool;
    final onlyWorkspaceData = argResults!['only-workspace-data'] as bool;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    var cleaned = 0;
    final clearCache = !onlyWorkspaceData;
    final clearWorkspaceData = !onlyCache;

    // Clear computation cache
    if (clearCache) {
      final cacheDir = Directory(
        p.join(workspace.rootPath, workspace.config.cacheConfig.directory),
      );
      if (cacheDir.existsSync()) {
        await cacheDir.delete(recursive: true);
        formatter.writeln('Cleared computation cache: ${cacheDir.path}');
        cleaned++;
      }
    }

    // Clear daemon socket/pid files
    if (clearWorkspaceData) {
      final daemonDir = Directory(p.join(workspace.rootPath, '.fx_daemon'));
      if (daemonDir.existsSync()) {
        await daemonDir.delete(recursive: true);
        formatter.writeln('Cleared daemon state: ${daemonDir.path}');
        cleaned++;
      }

      // Clear generated graph cache
      final graphCache = File(p.join(workspace.rootPath, '.fx_graph.json'));
      if (graphCache.existsSync()) {
        await graphCache.delete();
        formatter.writeln('Cleared graph cache: ${graphCache.path}');
        cleaned++;
      }
    }

    if (cleaned == 0) {
      formatter.writeln('Nothing to clean. Workspace is already fresh.');
    } else {
      formatter.writeln('\nSuccessfully reset $cleaned item(s).');
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
