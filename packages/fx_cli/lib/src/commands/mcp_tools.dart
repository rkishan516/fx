import 'dart:convert';

import 'package:fx_core/fx_core.dart';
import 'package:fx_generator/fx_generator.dart';

import 'mcp_ide_tools.dart';

/// Handles MCP tool calls against a workspace.
class McpToolHandler {
  final Workspace workspace;
  late final McpIdeToolHandler _ideTools;

  McpToolHandler({required this.workspace}) {
    _ideTools = McpIdeToolHandler(workspace: workspace);
  }

  Map<String, dynamic>? call(
    dynamic id,
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    switch (toolName) {
      case 'fx_list_projects':
        return _callListProjects(id, arguments);
      case 'fx_project_graph':
        return _callProjectGraph(id);
      case 'fx_project_details':
        return _callProjectDetails(id, arguments);
      case 'fx_run_target':
        return _callRunTarget(id, arguments);
      case 'fx_workspace':
        return _callWorkspace(id);
      case 'fx_workspace_path':
        return _callWorkspacePath(id);
      case 'fx_generators':
        return _callGenerators(id);
      case 'fx_generator_schema':
        return _callGeneratorSchema(id, arguments);
      default:
        return _ideTools.call(id, toolName, arguments);
    }
  }

  Map<String, dynamic> _callListProjects(
    dynamic id,
    Map<String, dynamic> arguments,
  ) {
    final typeFilter = arguments['type'] as String?;
    var projects = workspace.projects;
    if (typeFilter != null) {
      projects = projects.where((p) => p.type.toJson() == typeFilter).toList();
    }
    final data = projects
        .map(
          (p) => {
            'name': p.name,
            'type': p.type.toJson(),
            'path': p.path,
            'dependencies': p.dependencies,
          },
        )
        .toList();
    return toolResult(id, jsonEncode(data));
  }

  Map<String, dynamic> _callProjectGraph(dynamic id) {
    final nodes = workspace.projects
        .map((p) => {'name': p.name, 'type': p.type.toJson()})
        .toList();
    final edges = [
      for (final project in workspace.projects)
        for (final dep in project.dependencies)
          {'from': project.name, 'to': dep},
    ];
    return toolResult(id, jsonEncode({'nodes': nodes, 'edges': edges}));
  }

  Map<String, dynamic> _callProjectDetails(
    dynamic id,
    Map<String, dynamic> arguments,
  ) {
    final projectName = arguments['project'] as String?;
    if (projectName == null) {
      return errorResponse(id, -32602, 'Missing required parameter: project');
    }
    final project = workspace.projectByName(projectName);
    if (project == null) {
      return errorResponse(id, -32602, 'Project not found: $projectName');
    }
    final dependents = workspace.projects
        .where((p) => p.dependencies.contains(projectName))
        .map((p) => p.name)
        .toList();
    final data = {
      'name': project.name,
      'type': project.type.toJson(),
      'path': project.path,
      'tags': project.tags,
      'dependencies': project.dependencies,
      'dependents': dependents,
      'targets': {
        for (final entry in project.targets.entries)
          entry.key: {
            'executor': entry.value.executor,
            if (entry.value.dependsOn.isNotEmpty)
              'dependsOn': entry.value.dependsOn,
          },
      },
    };
    return toolResult(id, jsonEncode(data));
  }

  Map<String, dynamic> _callRunTarget(
    dynamic id,
    Map<String, dynamic> arguments,
  ) {
    final projectName = arguments['project'] as String?;
    final targetName = arguments['target'] as String?;
    if (projectName == null || targetName == null) {
      return errorResponse(
        id,
        -32602,
        'Missing required parameters: project, target',
      );
    }
    final project = workspace.projectByName(projectName);
    if (project == null) {
      return errorResponse(id, -32602, 'Project not found: $projectName');
    }
    final target = workspace.config.resolveTarget(
      targetName,
      projectTarget: project.targets[targetName],
    );
    if (target == null || target.executor.isEmpty) {
      return errorResponse(
        id,
        -32602,
        'Target "$targetName" not found on project $projectName',
      );
    }
    return toolResult(
      id,
      jsonEncode({
        'project': projectName,
        'target': targetName,
        'executor': target.executor,
        'workingDirectory': project.path,
        'command': 'cd ${project.path} && ${target.executor}',
      }),
    );
  }

  Map<String, dynamic> _callWorkspace(dynamic id) {
    final config = workspace.config;
    final data = {
      'rootPath': workspace.rootPath,
      'projectCount': workspace.projects.length,
      'packages': config.packages,
      'targets': {
        for (final entry in config.targets.entries)
          entry.key: {
            'executor': entry.value.executor,
            if (entry.value.dependsOn.isNotEmpty)
              'dependsOn': entry.value.dependsOn,
            if (entry.value.inputs.isNotEmpty) 'inputs': entry.value.inputs,
            if (entry.value.outputs.isNotEmpty) 'outputs': entry.value.outputs,
          },
      },
      'cache': {
        'enabled': config.cacheConfig.enabled,
        'directory': config.cacheConfig.directory,
      },
      'defaultBase': config.defaultBase,
      if (config.namedInputs.isNotEmpty)
        'namedInputs': {
          for (final entry in config.namedInputs.entries)
            entry.key: entry.value.patterns,
        },
      'projects': workspace.projects
          .map((p) => {'name': p.name, 'type': p.type.toJson()})
          .toList(),
    };
    return toolResult(id, jsonEncode(data));
  }

  Map<String, dynamic> _callWorkspacePath(dynamic id) {
    return toolResult(id, workspace.rootPath);
  }

  Map<String, dynamic> _callGenerators(dynamic id) {
    final registry = GeneratorRegistry.withBuiltIns();
    final data = registry.all
        .map((g) => {'name': g.name, 'description': g.description})
        .toList();
    return toolResult(id, jsonEncode(data));
  }

  Map<String, dynamic> _callGeneratorSchema(
    dynamic id,
    Map<String, dynamic> arguments,
  ) {
    final name = arguments['name'] as String?;
    if (name == null) {
      return errorResponse(id, -32602, 'Missing required parameter: name');
    }
    final registry = GeneratorRegistry.withBuiltIns();
    final generator = registry.get(name);
    if (generator == null) {
      return errorResponse(id, -32602, 'Generator not found: $name');
    }
    return toolResult(
      id,
      jsonEncode({
        'name': generator.name,
        'description': generator.description,
        'arguments': {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'Name for the generated project.',
            },
            'directory': {
              'type': 'string',
              'description': 'Directory to generate into (optional).',
            },
          },
          'required': ['name'],
        },
      }),
    );
  }

  // -- Shared helpers --

  static Map<String, dynamic> toolResult(dynamic id, String text) => {
    'jsonrpc': '2.0',
    'id': id,
    'result': {
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  };

  static Map<String, dynamic> errorResponse(
    dynamic id,
    int code,
    String message,
  ) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };

  static Map<String, dynamic> makeTool(
    String name,
    String desc,
    Map<String, dynamic> props, {
    List<String>? required,
  }) => {
    'name': name,
    'description': desc,
    'inputSchema': {
      'type': 'object',
      'properties': props,
      'required': ?required,
    },
  };

  /// All tool definitions (workspace + IDE).
  static final toolDefinitions = [
    makeTool('fx_list_projects', 'List all projects with types and paths.', {
      'type': {
        'type': 'string',
        'description': 'Filter: app, package, or plugin.',
        'enum': ['app', 'package', 'plugin'],
      },
    }),
    makeTool(
      'fx_project_graph',
      'Get the dependency graph as JSON (nodes + edges).',
      {},
    ),
    makeTool(
      'fx_project_details',
      'Get details about a project (deps, dependents, targets).',
      {
        'project': {'type': 'string', 'description': 'Project name.'},
      },
      required: ['project'],
    ),
    makeTool(
      'fx_run_target',
      'Get the command to run a target on a project.',
      {
        'project': {'type': 'string', 'description': 'Project name.'},
        'target': {
          'type': 'string',
          'description': 'Target name (e.g., test, build).',
        },
      },
      required: ['project', 'target'],
    ),
    makeTool(
      'fx_workspace',
      'Get full workspace configuration: projects, targets, cache, named inputs.',
      {},
    ),
    makeTool('fx_workspace_path', 'Get the workspace root path.', {}),
    makeTool('fx_generators', 'List available code generators.', {}),
    makeTool(
      'fx_generator_schema',
      'Get the JSON schema for a specific generator.',
      {
        'name': {
          'type': 'string',
          'description': 'Generator name (e.g., dart_package, flutter_app).',
        },
      },
      required: ['name'],
    ),
    ...McpIdeToolHandler.toolDefinitions,
  ];
}
