import 'dart:convert';
import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('McpCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp('fx_mcp_test_');
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('handles initialize request', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'test', 'version': '1.0'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final output = buffer.toString().trim();
      final response = jsonDecode(output) as Map<String, dynamic>;
      expect(response['jsonrpc'], '2.0');
      expect(response['id'], 1);
      final result = response['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], isNotNull);
      expect(result['serverInfo'], isNotNull);
      final serverInfo = result['serverInfo'] as Map<String, dynamic>;
      expect(serverInfo['name'], 'fx');
    });

    test('handles tools/list request', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final output = buffer.toString().trim();
      final response = jsonDecode(output) as Map<String, dynamic>;
      expect(response['id'], 2);
      final result = response['result'] as Map<String, dynamic>;
      final tools = result['tools'] as List;
      expect(tools, isNotEmpty);

      final toolNames = tools.map((t) => (t as Map)['name'] as String).toList();
      expect(toolNames, contains('fx_list_projects'));
      expect(toolNames, contains('fx_project_graph'));
      expect(toolNames, contains('fx_project_details'));
      expect(toolNames, contains('fx_run_target'));
    });

    test('tools/call fx_list_projects returns projects', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {'name': 'fx_list_projects', 'arguments': {}},
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final output = buffer.toString().trim();
      final response = jsonDecode(output) as Map<String, dynamic>;
      expect(response['id'], 3);
      final result = response['result'] as Map<String, dynamic>;
      final content = result['content'] as List;
      expect(content, isNotEmpty);

      final text = (content.first as Map)['text'] as String;
      final projects = jsonDecode(text) as List;
      final names = projects.map((p) => (p as Map)['name']).toSet();
      expect(names, containsAll(['pkg_a', 'pkg_b']));
    });

    test('tools/call fx_project_graph returns nodes and edges', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {'name': 'fx_project_graph', 'arguments': {}},
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final output = buffer.toString().trim();
      final response = jsonDecode(output) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final content = result['content'] as List;
      final text = (content.first as Map)['text'] as String;
      final graph = jsonDecode(text) as Map<String, dynamic>;
      expect(graph.containsKey('nodes'), isTrue);
      expect(graph.containsKey('edges'), isTrue);
    });

    test('tools/call fx_project_details returns project info', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {
          'name': 'fx_project_details',
          'arguments': {'project': 'pkg_a'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final output = buffer.toString().trim();
      final response = jsonDecode(output) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final content = result['content'] as List;
      final text = (content.first as Map)['text'] as String;
      final details = jsonDecode(text) as Map<String, dynamic>;
      expect(details['name'], 'pkg_a');
      expect(details.containsKey('type'), isTrue);
      expect(details.containsKey('path'), isTrue);
    });

    test('tools/call unknown tool returns error', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 6,
        'method': 'tools/call',
        'params': {'name': 'nonexistent_tool', 'arguments': {}},
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final output = buffer.toString().trim();
      final response = jsonDecode(output) as Map<String, dynamic>;
      expect(response['id'], 6);
      expect(response.containsKey('error'), isTrue);
    });

    test('tools/call fx_workspace returns config and projects', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 10,
        'method': 'tools/call',
        'params': {'name': 'fx_workspace', 'arguments': {}},
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final ws = jsonDecode(text['text'] as String) as Map<String, dynamic>;
      expect(ws['rootPath'], workspaceDir.path);
      expect(ws['projectCount'], 2);
      expect((ws['targets'] as Map).containsKey('test'), isTrue);
    });

    test('tools/call fx_workspace_path returns root path', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 11,
        'method': 'tools/call',
        'params': {'name': 'fx_workspace_path', 'arguments': {}},
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      expect(text['text'], workspaceDir.path);
    });

    test('tools/call fx_generators returns generator list', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 12,
        'method': 'tools/call',
        'params': {'name': 'fx_generators', 'arguments': {}},
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final generators = jsonDecode(text['text'] as String) as List;
      expect(generators, isNotEmpty);
      final names = generators.map((g) => (g as Map)['name']).toList();
      expect(names, contains('dart_package'));
    });

    test('tools/call fx_generator_schema returns schema', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 13,
        'method': 'tools/call',
        'params': {
          'name': 'fx_generator_schema',
          'arguments': {'name': 'dart_package'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final schema = jsonDecode(text['text'] as String) as Map<String, dynamic>;
      expect(schema['name'], 'dart_package');
      expect(schema.containsKey('arguments'), isTrue);
    });

    test('tools/list includes all 14 tools', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 14,
        'method': 'tools/list',
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final tools = result['tools'] as List;
      expect(tools, hasLength(14));
      final names = tools.map((t) => (t as Map)['name']).toSet();
      expect(
        names,
        containsAll([
          'fx_list_projects',
          'fx_project_graph',
          'fx_project_details',
          'fx_run_target',
          'fx_workspace',
          'fx_workspace_path',
          'fx_generators',
          'fx_generator_schema',
          'fx_run_generator',
          'fx_visualize_graph',
          'fx_running_tasks',
          'fx_task_output',
          'fx_docs',
          'fx_available_plugins',
        ]),
      );
    });

    test('tools/call fx_run_generator returns generator info', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 20,
        'method': 'tools/call',
        'params': {
          'name': 'fx_run_generator',
          'arguments': {'name': 'dart_package', 'projectName': 'my_lib'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final data = jsonDecode(text['text'] as String) as Map<String, dynamic>;
      expect(data['generator'], 'dart_package');
      expect(data['projectName'], 'my_lib');
      expect(data['command'], contains('fx generate'));
    });

    test('tools/call fx_run_generator error on missing params', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 21,
        'method': 'tools/call',
        'params': {
          'name': 'fx_run_generator',
          'arguments': {'name': 'dart_package'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      expect(response.containsKey('error'), isTrue);
    });

    test('tools/call fx_visualize_graph returns command info', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 22,
        'method': 'tools/call',
        'params': {
          'name': 'fx_visualize_graph',
          'arguments': {'port': 5000},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final data = jsonDecode(text['text'] as String) as Map<String, dynamic>;
      expect(data['command'], contains('--port=5000'));
      expect(data['url'], 'http://localhost:5000');
    });

    test('tools/call fx_running_tasks returns daemon status', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 23,
        'method': 'tools/call',
        'params': {'name': 'fx_running_tasks', 'arguments': {}},
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final data = jsonDecode(text['text'] as String) as Map<String, dynamic>;
      expect(data['daemon'], isA<Map<String, dynamic>>());
      expect(data['daemon']['running'], isFalse);
      expect(data['graphCache'], isA<Map<String, dynamic>>());
    });

    test('tools/call fx_task_output returns no-cache hint', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 24,
        'method': 'tools/call',
        'params': {
          'name': 'fx_task_output',
          'arguments': {'project': 'pkg_a', 'target': 'test'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final data = jsonDecode(text['text'] as String) as Map<String, dynamic>;
      expect(data['project'], 'pkg_a');
      expect(data['target'], 'test');
      expect(data['source'], 'none');
      expect(data['hint'], contains('No cached output'));
    });

    test('tools/call fx_task_output error on missing params', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 25,
        'method': 'tools/call',
        'params': {
          'name': 'fx_task_output',
          'arguments': {'project': 'pkg_a'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      expect(response.containsKey('error'), isTrue);
    });

    test('tools/call fx_docs returns matching sections', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 30,
        'method': 'tools/call',
        'params': {
          'name': 'fx_docs',
          'arguments': {'query': 'cache'},
        },
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final response =
          jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
      final result = response['result'] as Map<String, dynamic>;
      final text = (result['content'] as List).first as Map<String, dynamic>;
      final sections = jsonDecode(text['text'] as String) as List;
      expect(sections, isNotEmpty);
      final titles = sections
          .map((s) => (s as Map)['title'] as String)
          .toList();
      expect(titles, contains('fx cache'));
    });

    test(
      'tools/call fx_docs returns no-match hint for unknown query',
      () async {
        final buffer = StringBuffer();
        final runner = FxCommandRunner(outputSink: buffer);

        final request = jsonEncode({
          'jsonrpc': '2.0',
          'id': 31,
          'method': 'tools/call',
          'params': {
            'name': 'fx_docs',
            'arguments': {'query': 'xyznonexistent'},
          },
        });

        await runner.run([
          'mcp',
          '--workspace',
          workspaceDir.path,
          '--input',
          request,
        ]);

        final response =
            jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
        final result = response['result'] as Map<String, dynamic>;
        final text = (result['content'] as List).first as Map<String, dynamic>;
        final sections = jsonDecode(text['text'] as String) as List;
        expect(sections, hasLength(1));
        expect((sections.first as Map)['title'], 'No results');
      },
    );

    test(
      'tools/call fx_available_plugins returns built-in generators',
      () async {
        final buffer = StringBuffer();
        final runner = FxCommandRunner(outputSink: buffer);

        final request = jsonEncode({
          'jsonrpc': '2.0',
          'id': 32,
          'method': 'tools/call',
          'params': {'name': 'fx_available_plugins', 'arguments': {}},
        });

        await runner.run([
          'mcp',
          '--workspace',
          workspaceDir.path,
          '--input',
          request,
        ]);

        final response =
            jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;
        final result = response['result'] as Map<String, dynamic>;
        final text = (result['content'] as List).first as Map<String, dynamic>;
        final data = jsonDecode(text['text'] as String) as Map<String, dynamic>;
        final builtIn = data['builtIn'] as List;
        expect(builtIn, isNotEmpty);
        final names = builtIn.map((g) => (g as Map)['name']).toList();
        expect(names, contains('dart_package'));
        expect(data['localPlugins'], isList);
      },
    );

    test('handles unknown method with error', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 7,
        'method': 'unknown/method',
      });

      await runner.run([
        'mcp',
        '--workspace',
        workspaceDir.path,
        '--input',
        request,
      ]);

      final output = buffer.toString().trim();
      final response = jsonDecode(output) as Map<String, dynamic>;
      expect(response['id'], 7);
      expect(response.containsKey('error'), isTrue);
      final error = response['error'] as Map<String, dynamic>;
      expect(error['code'], -32601); // Method not found
    });
  });
}

Future<void> _createMinimalWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: test_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/pkg_a
  - packages/pkg_b

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
    build:
      executor: dart compile
''');

  for (final name in ['pkg_a', 'pkg_b']) {
    final pkgDir = Directory(p.join(root, 'packages', name));
    await pkgDir.create(recursive: true);
    final deps = name == 'pkg_b'
        ? '\ndependencies:\n  pkg_a:\n    path: ../pkg_a'
        : '';
    await File(p.join(pkgDir.path, 'pubspec.yaml')).writeAsString('''
name: $name
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.11.1$deps
''');
  }
}
