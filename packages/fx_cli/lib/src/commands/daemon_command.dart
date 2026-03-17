import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:path/path.dart' as p;

import '../output/output_formatter.dart';

/// `fx daemon` — Background daemon for project graph watching.
///
/// Nx uses a daemon to keep a project graph in memory and watch for
/// changes. This implements a similar concept for fx.
class DaemonCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'daemon';

  @override
  String get description =>
      'Start or manage the fx background daemon.\n\n'
      'Subcommands:\n'
      '  fx daemon start    — Start the daemon\n'
      '  fx daemon stop     — Stop the daemon\n'
      '  fx daemon status   — Check daemon status\n'
      '  fx daemon graph    — Get cached project graph';

  DaemonCommand({required this.formatter}) {
    argParser.addOption(
      'workspace',
      help: 'Path to workspace root (for testing).',
      hide: true,
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    final workspacePath = argResults!['workspace'] as String?;

    if (rest.isEmpty) {
      throw UsageException('Usage: fx daemon start|stop|status|graph', usage);
    }

    final root = workspacePath ?? _findWorkspaceRoot();

    switch (rest[0]) {
      case 'start':
        await _start(root);
      case 'stop':
        await _stop(root);
      case 'status':
        await _status(root);
      case 'graph':
        await _graph(root);
      default:
        throw UsageException('Unknown subcommand: ${rest[0]}', usage);
    }
  }

  String get _daemonDir => '.fx_daemon';

  File _pidFile(String root) => File(p.join(root, _daemonDir, 'daemon.pid'));
  File _graphCacheFile(String root) =>
      File(p.join(root, _daemonDir, 'graph.json'));

  Future<void> _start(String root) async {
    final dir = Directory(p.join(root, _daemonDir));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Check if already running
    final pidFile = _pidFile(root);
    if (pidFile.existsSync()) {
      final pid = int.tryParse(pidFile.readAsStringSync().trim());
      if (pid != null) {
        try {
          Process.killPid(pid, ProcessSignal.sigusr1);
          formatter.writeln('Daemon already running (pid: $pid).');
          return;
        } catch (_) {
          // Process doesn't exist, clean up stale pid
          pidFile.deleteSync();
        }
      }
    }

    // Build and cache the project graph
    final workspace = await WorkspaceLoader.load(root);
    final graph = ProjectGraph.build(workspace.projects);

    // Write graph cache
    _writeGraphCache(root, workspace, graph);

    // Write our own PID (in a real implementation, this would fork a
    // background process; for now we just cache the graph)
    pidFile.writeAsStringSync('$pid');

    formatter.writeln('Daemon started (pid: $pid).');
    formatter.writeln(
      'Graph cached with ${workspace.projects.length} projects.',
    );
  }

  Future<void> _stop(String root) async {
    final pidFile = _pidFile(root);
    if (!pidFile.existsSync()) {
      formatter.writeln('Daemon is not running.');
      return;
    }

    final pid = int.tryParse(pidFile.readAsStringSync().trim());
    pidFile.deleteSync();

    if (pid != null) {
      try {
        Process.killPid(pid);
      } catch (_) {
        // Already stopped
      }
    }

    formatter.writeln('Daemon stopped.');
  }

  Future<void> _status(String root) async {
    final pidFile = _pidFile(root);
    if (!pidFile.existsSync()) {
      formatter.writeln('Daemon: not running');
      return;
    }

    final pid = int.tryParse(pidFile.readAsStringSync().trim());
    final graphCache = _graphCacheFile(root);
    final hasCachedGraph = graphCache.existsSync();

    formatter.writeln('Daemon: running (pid: $pid)');
    formatter.writeln(
      'Graph cache: ${hasCachedGraph ? 'available' : 'not built'}',
    );

    if (hasCachedGraph) {
      final stat = graphCache.statSync();
      formatter.writeln('Last updated: ${stat.modified}');
    }
  }

  Future<void> _graph(String root) async {
    final graphCache = _graphCacheFile(root);
    if (!graphCache.existsSync()) {
      // Build on demand if not cached
      final workspace = await WorkspaceLoader.load(root);
      final graph = ProjectGraph.build(workspace.projects);
      _writeGraphCache(root, workspace, graph);
    }

    final content = graphCache.readAsStringSync();
    formatter.writeln(content);
  }

  void _writeGraphCache(String root, Workspace workspace, ProjectGraph graph) {
    final dir = Directory(p.join(root, _daemonDir));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final data = {
      'projects': [
        for (final project in workspace.projects)
          {
            'name': project.name,
            'type': project.type.toJson(),
            'path': project.path,
            'dependencies': project.dependencies,
          },
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };

    _graphCacheFile(
      root,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
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
