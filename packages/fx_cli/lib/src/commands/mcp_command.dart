import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';

import '../output/output_formatter.dart';
import 'mcp_tools.dart';

/// `fx mcp` — Start an MCP (Model Context Protocol) server over stdio.
///
/// Exposes workspace tools to AI coding assistants via JSON-RPC 2.0.
class McpCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'mcp';

  @override
  String get description =>
      'Start an MCP server exposing workspace tools for AI assistants.';

  McpCommand({required this.formatter}) {
    argParser
      ..addOption(
        'workspace',
        help: 'Path to workspace root (for testing).',
        hide: true,
      )
      ..addOption(
        'input',
        help: 'Single JSON-RPC request to process (for testing).',
        hide: true,
      );
  }

  @override
  Future<void> run() async {
    final workspacePath = argResults!['workspace'] as String?;
    final singleInput = argResults!['input'] as String?;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    final server = _McpServer(workspace: workspace, formatter: formatter);

    if (singleInput != null) {
      final request = jsonDecode(singleInput) as Map<String, dynamic>;
      final response = await server.handleRequest(request);
      formatter.writeln(jsonEncode(response));
    } else {
      await for (final line
          in stdin
              .transform(const Utf8Decoder())
              .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final request = jsonDecode(line) as Map<String, dynamic>;
          final response = await server.handleRequest(request);
          stdout.writeln(jsonEncode(response));
        } on FormatException {
          stdout.writeln(
            jsonEncode(
              McpToolHandler.errorResponse(null, -32700, 'Parse error'),
            ),
          );
        }
      }
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

class _McpServer {
  final Workspace workspace;
  final OutputFormatter formatter;
  late final McpToolHandler _tools;

  _McpServer({required this.workspace, required this.formatter}) {
    _tools = McpToolHandler(workspace: workspace);
  }

  Future<Map<String, dynamic>> handleRequest(
    Map<String, dynamic> request,
  ) async {
    final method = request['method'] as String?;
    final id = request['id'];

    switch (method) {
      case 'initialize':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'tools': {'listChanged': false},
            },
            'serverInfo': {'name': 'fx', 'version': '0.1.0'},
          },
        };
      case 'tools/list':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {'tools': McpToolHandler.toolDefinitions},
        };
      case 'tools/call':
        final params = request['params'] as Map<String, dynamic>?;
        final toolName = params?['name'] as String?;
        final arguments =
            params?['arguments'] as Map<String, dynamic>? ?? const {};
        final result = _tools.call(id, toolName ?? '', arguments);
        return result ??
            McpToolHandler.errorResponse(id, -32602, 'Unknown tool: $toolName');
      default:
        return McpToolHandler.errorResponse(
          id,
          -32601,
          'Method not found: $method',
        );
    }
  }
}
