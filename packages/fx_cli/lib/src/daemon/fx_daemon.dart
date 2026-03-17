import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fx_cache/fx_cache.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:path/path.dart' as p;

/// Background daemon that watches workspace files and keeps the project graph
/// in memory for fast CLI responses.
///
/// Communicates via a Unix domain socket (or TCP on Windows).
class FxDaemon {
  final String workspaceRoot;
  Workspace? _workspace;
  ProjectGraph? _graph;
  final List<StreamSubscription<FileSystemEvent>> _watchers = [];
  ServerSocket? _server;
  Timer? _debounce;
  bool _needsRefresh = true;

  /// Lock to serialise concurrent _refresh() calls.
  /// If non-null, a refresh is already in progress or queued.
  Completer<void>? _refreshLock;
  bool _refreshQueued = false;

  /// Optional callback invoked at the start of each real refresh (for testing).
  void Function()? onRefresh;

  late final GraphCache _graphCache;

  FxDaemon({required this.workspaceRoot}) {
    _graphCache = GraphCache(
      cacheFile: File(p.join(workspaceRoot, '.fx_daemon', 'graph_cache.json')),
    );
  }

  /// Start the daemon, listen for requests on a socket.
  Future<void> start({int port = 4210}) async {
    await _refresh();

    // Watch for pubspec.yaml and dart file changes
    _watchDirectory(workspaceRoot);

    // Start the server
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handleConnection);

    // Write PID file
    final daemonDir = Directory(p.join(workspaceRoot, '.fx_daemon'));
    await daemonDir.create(recursive: true);
    await File(p.join(daemonDir.path, 'daemon.pid')).writeAsString('$pid');
    await File(p.join(daemonDir.path, 'daemon.port')).writeAsString('$port');
  }

  /// Stop the daemon.
  Future<void> stop() async {
    for (final w in _watchers) {
      await w.cancel();
    }
    _watchers.clear();
    await _server?.close();

    // Clean up PID file
    final pidFile = File(p.join(workspaceRoot, '.fx_daemon', 'daemon.pid'));
    if (pidFile.existsSync()) await pidFile.delete();
  }

  void _watchDirectory(String dir) {
    final directory = Directory(dir);
    if (!directory.existsSync()) return;

    final sub = directory.watch(recursive: true).listen((event) {
      if (_isRelevantFile(event.path)) {
        _needsRefresh = true;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          _scheduleRefresh();
        });
      }
    });

    _watchers.add(sub);
  }

  bool _isRelevantFile(String path) {
    return path.endsWith('pubspec.yaml') ||
        path.endsWith('.dart') ||
        path.endsWith('fx.yaml');
  }

  /// Schedule a refresh, collapsing concurrent calls.
  ///
  /// At most one refresh runs at a time; if another is already running, at most
  /// one additional call is queued (subsequent calls are dropped).
  void _scheduleRefresh() {
    if (_refreshLock == null) {
      // No refresh in progress — start one immediately.
      _refresh();
    } else {
      // A refresh is in progress — queue one more if not already queued.
      _refreshQueued = true;
    }
  }

  /// Exposed for testing: trigger a refresh and return a future that completes
  /// when the refresh is done (or the queued refresh is done).
  Future<void> triggerRefreshForTest() => _refresh();

  Future<void> _refresh() async {
    // Acquire lock.
    if (_refreshLock != null) {
      // Already running — wait for it and return.
      _refreshQueued = true;
      await _refreshLock!.future;
      return;
    }

    final completer = Completer<void>();
    _refreshLock = completer;

    try {
      onRefresh?.call();
      await _doRefresh();
    } finally {
      _refreshLock = null;
      completer.complete();
    }

    // If another refresh was queued while we were running, do it now.
    if (_refreshQueued) {
      _refreshQueued = false;
      await _refresh();
    }
  }

  Future<void> _doRefresh() async {
    try {
      _workspace = await WorkspaceLoader.load(workspaceRoot);

      // Try incremental rebuild via cache
      final changedPkgs = await _graphCache.changedPackages(
        projects: _workspace!.projects,
        workspaceRoot: workspaceRoot,
      );

      if (changedPkgs.isEmpty && _graph != null) {
        // Nothing changed — use existing graph
        _needsRefresh = false;
        return;
      }

      // For now rebuild the full graph; incremental merge can be done in a
      // future optimisation without breaking the public API.
      _graph = ProjectGraph.build(_workspace!.projects);
      _needsRefresh = false;

      // Persist cache for next run
      final currentHash = await const ProcessGitRunner().currentHash(
        workspaceRoot,
      );
      await _graphCache.save(
        projects: _workspace!.projects,
        graph: _graph!,
        gitHash: currentHash,
      );
    } catch (_) {
      // Silently ignore refresh errors (file might be mid-write)
    }
  }

  Future<void> _handleConnection(Socket socket) async {
    final data = await socket.cast<List<int>>().transform(utf8.decoder).join();
    final request = data.trim();

    if (_needsRefresh) await _refresh();

    String response;
    switch (request) {
      case 'graph':
        if (_graph == null || _workspace == null) {
          response = jsonEncode({'error': 'workspace not loaded'});
        } else {
          final nodes = _workspace!.projects.map((p) => p.name).toList();
          final edges = <Map<String, String>>[];
          for (final p in _workspace!.projects) {
            for (final dep in _graph!.dependenciesOf(p.name)) {
              edges.add({'from': p.name, 'to': dep});
            }
          }
          response = jsonEncode({'nodes': nodes, 'edges': edges});
        }
      case 'projects':
        response = jsonEncode(
          _workspace?.projects.map((p) => p.toJson()).toList() ?? [],
        );
      case 'ping':
        response = 'pong';
      case 'shutdown':
        response = 'ok';
        socket.write(response);
        await socket.close();
        await stop();
        exit(0);
      default:
        response = jsonEncode({'error': 'unknown command: $request'});
    }

    socket.write(response);
    await socket.close();
  }

  /// Query a running daemon.
  ///
  /// Connects once, sends [command] (half-closes the write side), then reads
  /// the full response until the server closes the connection.
  static Future<String?> query(String workspaceRoot, String command) async {
    try {
      final portFile = File(p.join(workspaceRoot, '.fx_daemon', 'daemon.port'));
      if (!portFile.existsSync()) return null;

      final port = int.parse(portFile.readAsStringSync().trim());
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.write(command);
      // Half-close the write side so the server's join() returns.
      await socket.close();
      final response = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join();
      return response;
    } catch (_) {
      return null;
    }
  }
}
