import 'dart:convert';
import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:fx_generator/fx_generator.dart';
import 'package:path/path.dart' as p;

import 'mcp_docs.dart';
import 'mcp_tools.dart';

/// IDE-specific MCP tool handlers (graph visualization, generators, task monitoring).
class McpIdeToolHandler {
  final Workspace workspace;

  McpIdeToolHandler({required this.workspace});

  /// Returns a response if [toolName] is handled, null otherwise.
  Map<String, dynamic>? call(
    dynamic id,
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    switch (toolName) {
      case 'fx_run_generator':
        return _callRunGenerator(id, arguments);
      case 'fx_visualize_graph':
        return _callVisualizeGraph(id, arguments);
      case 'fx_running_tasks':
        return _callRunningTasks(id);
      case 'fx_task_output':
        return _callTaskOutput(id, arguments);
      case 'fx_docs':
        return _callDocs(id, arguments);
      case 'fx_available_plugins':
        return _callAvailablePlugins(id);
      default:
        return null;
    }
  }

  Map<String, dynamic> _callRunGenerator(
    dynamic id,
    Map<String, dynamic> arguments,
  ) {
    final name = arguments['name'] as String?;
    final projectName = arguments['projectName'] as String?;
    final directory = arguments['directory'] as String?;
    if (name == null || projectName == null) {
      return McpToolHandler.errorResponse(
        id,
        -32602,
        'Missing required parameters: name, projectName',
      );
    }
    final registry = GeneratorRegistry.withBuiltIns();
    final generator = registry.get(name);
    if (generator == null) {
      return McpToolHandler.errorResponse(
        id,
        -32602,
        'Generator not found: $name',
      );
    }
    final outputDir =
        directory ?? p.join(workspace.rootPath, 'packages', projectName);
    return McpToolHandler.toolResult(
      id,
      jsonEncode({
        'generator': name,
        'projectName': projectName,
        'outputDirectory': outputDir,
        'command':
            'fx generate $name $projectName'
            '${directory != null ? ' --directory=$directory' : ''}',
        'description': generator.description,
      }),
    );
  }

  Map<String, dynamic> _callVisualizeGraph(
    dynamic id,
    Map<String, dynamic> arguments,
  ) {
    final port = arguments['port'] as int? ?? 4211;
    return McpToolHandler.toolResult(
      id,
      jsonEncode({
        'command': 'fx graph --web --port=$port',
        'url': 'http://localhost:$port',
        'description':
            'Opens an interactive dependency graph visualization '
            'in the browser. Run the command to start the server.',
      }),
    );
  }

  Map<String, dynamic> _callRunningTasks(dynamic id) {
    final daemonDir = p.join(workspace.rootPath, '.fx_daemon');
    final pidFile = File(p.join(daemonDir, 'daemon.pid'));
    final graphFile = File(p.join(daemonDir, 'graph.json'));

    final daemonRunning = pidFile.existsSync();
    final graphCached = graphFile.existsSync();
    String? graphTimestamp;
    if (graphCached) {
      try {
        final content =
            jsonDecode(graphFile.readAsStringSync()) as Map<String, dynamic>;
        graphTimestamp = content['timestamp'] as String?;
      } catch (_) {}
    }

    return McpToolHandler.toolResult(
      id,
      jsonEncode({
        'daemon': {
          'running': daemonRunning,
          if (daemonRunning) 'pid': pidFile.readAsStringSync().trim(),
        },
        'graphCache': {
          'available': graphCached,
          'lastUpdated': ?graphTimestamp,
        },
        'hint': daemonRunning
            ? 'Daemon is running. Use `fx daemon graph` to get cached graph.'
            : 'Daemon is not running. Start with `fx daemon start`.',
      }),
    );
  }

  Map<String, dynamic> _callTaskOutput(
    dynamic id,
    Map<String, dynamic> arguments,
  ) {
    final project = arguments['project'] as String?;
    final target = arguments['target'] as String?;
    if (project == null || target == null) {
      return McpToolHandler.errorResponse(
        id,
        -32602,
        'Missing required parameters: project, target',
      );
    }
    final cacheDir = p.join(
      workspace.rootPath,
      workspace.config.cacheConfig.directory,
      project,
      target,
    );
    final outputFile = File(p.join(cacheDir, 'output'));
    if (outputFile.existsSync()) {
      return McpToolHandler.toolResult(
        id,
        jsonEncode({
          'project': project,
          'target': target,
          'source': 'cache',
          'output': outputFile.readAsStringSync(),
        }),
      );
    }
    return McpToolHandler.toolResult(
      id,
      jsonEncode({
        'project': project,
        'target': target,
        'source': 'none',
        'output': null,
        'hint': 'No cached output found. Run `fx run $project $target` first.',
      }),
    );
  }

  Map<String, dynamic> _callDocs(dynamic id, Map<String, dynamic> arguments) {
    final query = (arguments['query'] as String? ?? '').toLowerCase();
    final sections = <Map<String, String>>[];
    for (final entry in fxDocSections) {
      if (query.isEmpty ||
          entry['title']!.toLowerCase().contains(query) ||
          entry['content']!.toLowerCase().contains(query)) {
        sections.add(entry);
      }
    }
    if (sections.isEmpty) {
      sections.add({
        'title': 'No results',
        'content':
            'No documentation matched "$query". '
            'Try broader terms like "init", "run", "generate", "graph", '
            '"cache", "affected", or "workspace".',
      });
    }
    return McpToolHandler.toolResult(id, jsonEncode(sections));
  }

  Map<String, dynamic> _callAvailablePlugins(dynamic id) {
    final registry = GeneratorRegistry.withBuiltIns();
    final builtIn = registry.all
        .map(
          (g) => {
            'name': g.name,
            'description': g.description,
            'type': 'built-in',
          },
        )
        .toList();

    // Discover workspace-local plugins
    final pluginPaths = workspace.config.generators;
    final localPlugins = <Map<String, String>>[];
    for (final searchPath in pluginPaths) {
      final dir = Directory(p.join(workspace.rootPath, searchPath));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync()) {
        if (entity is! Directory) continue;
        final pubspec = File(p.join(entity.path, 'pubspec.yaml'));
        final bin = File(p.join(entity.path, 'bin', 'generator.dart'));
        if (pubspec.existsSync() && bin.existsSync()) {
          localPlugins.add({
            'name': p.basename(entity.path),
            'path': entity.path,
            'type': 'local-plugin',
          });
        }
      }
    }

    return McpToolHandler.toolResult(
      id,
      jsonEncode({
        'builtIn': builtIn,
        'localPlugins': localPlugins,
        'hint': localPlugins.isEmpty
            ? 'No local generator plugins found. '
                  'Configure generatorPlugins in pubspec.yaml fx section.'
            : '${localPlugins.length} local plugin(s) discovered.',
      }),
    );
  }

  /// Tool definitions for IDE-specific tools.
  static final toolDefinitions = [
    McpToolHandler.makeTool(
      'fx_run_generator',
      'Get the command to run a code generator with prefilled options.',
      {
        'name': {'type': 'string', 'description': 'Generator name.'},
        'projectName': {
          'type': 'string',
          'description': 'Name for the new project.',
        },
        'directory': {
          'type': 'string',
          'description': 'Output directory (optional).',
        },
      },
      required: ['name', 'projectName'],
    ),
    McpToolHandler.makeTool(
      'fx_visualize_graph',
      'Open an interactive project graph visualization in the browser.',
      {
        'port': {
          'type': 'integer',
          'description': 'Port for the web server (default: 4211).',
        },
      },
    ),
    McpToolHandler.makeTool(
      'fx_running_tasks',
      'List daemon status and any running task information.',
      {},
    ),
    McpToolHandler.makeTool(
      'fx_task_output',
      'Get cached terminal output for a previously run task.',
      {
        'project': {'type': 'string', 'description': 'Project name.'},
        'target': {'type': 'string', 'description': 'Target name.'},
      },
      required: ['project', 'target'],
    ),
    McpToolHandler.makeTool(
      'fx_docs',
      'Search fx documentation for information about commands, '
          'configuration, and concepts.',
      {
        'query': {
          'type': 'string',
          'description':
              'Search query (e.g., "cache", "affected", '
              '"workspace configuration").',
        },
      },
      required: ['query'],
    ),
    McpToolHandler.makeTool(
      'fx_available_plugins',
      'List available built-in generators and discovered local '
          'generator plugins.',
      {},
    ),
  ];
}
