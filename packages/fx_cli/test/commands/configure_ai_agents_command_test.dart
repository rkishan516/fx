import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ConfigureAiAgentsCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_ai_agents_test_',
      );
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('generates config files for all agents by default', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'configure-ai-agents',
        '--workspace',
        workspaceDir.path,
        '--no-interactive',
      ]);

      // Check Claude config
      final claudeFile = File(
        p.join(workspaceDir.path, '.claude', 'rules', 'fx-workspace.md'),
      );
      expect(claudeFile.existsSync(), isTrue);
      final claudeContent = claudeFile.readAsStringSync();
      expect(claudeContent, contains('pkg_a'));
      expect(claudeContent, contains('pkg_b'));

      // Check Cursor config
      final cursorFile = File(p.join(workspaceDir.path, '.cursorrules'));
      expect(cursorFile.existsSync(), isTrue);

      // Check Copilot config
      final copilotFile = File(
        p.join(workspaceDir.path, '.github', 'copilot-instructions.md'),
      );
      expect(copilotFile.existsSync(), isTrue);

      // Check Gemini config
      final geminiFile = File(
        p.join(workspaceDir.path, '.gemini', 'rules', 'fx-workspace.md'),
      );
      expect(geminiFile.existsSync(), isTrue);

      // Check OpenCode config
      final openCodeFile = File(
        p.join(workspaceDir.path, '.opencode', 'rules', 'fx-workspace.md'),
      );
      expect(openCodeFile.existsSync(), isTrue);

      // Check Codex config
      final codexFile = File(p.join(workspaceDir.path, 'codex.md'));
      expect(codexFile.existsSync(), isTrue);
    });

    test('--agents flag filters which agents to configure', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'configure-ai-agents',
        '--workspace',
        workspaceDir.path,
        '--no-interactive',
        '--agents',
        'claude,cursor',
      ]);

      // Claude and Cursor should exist
      expect(
        File(
          p.join(workspaceDir.path, '.claude', 'rules', 'fx-workspace.md'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(workspaceDir.path, '.cursorrules')).existsSync(),
        isTrue,
      );

      // Others should NOT exist
      expect(
        File(
          p.join(workspaceDir.path, '.github', 'copilot-instructions.md'),
        ).existsSync(),
        isFalse,
      );
      expect(File(p.join(workspaceDir.path, 'codex.md')).existsSync(), isFalse);
    });

    test('generated content includes workspace targets', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'configure-ai-agents',
        '--workspace',
        workspaceDir.path,
        '--no-interactive',
        '--agents',
        'claude',
      ]);

      final content = File(
        p.join(workspaceDir.path, '.claude', 'rules', 'fx-workspace.md'),
      ).readAsStringSync();
      expect(content, contains('test'));
      expect(content, contains('build'));
      expect(content, contains('fx run'));
    });

    test('generated content includes dependency information', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'configure-ai-agents',
        '--workspace',
        workspaceDir.path,
        '--no-interactive',
        '--agents',
        'claude',
      ]);

      final content = File(
        p.join(workspaceDir.path, '.claude', 'rules', 'fx-workspace.md'),
      ).readAsStringSync();
      // pkg_b depends on pkg_a
      expect(content, contains('pkg_a'));
      expect(content, contains('pkg_b'));
    });

    test('--check returns success when configs are up-to-date', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      // First generate
      await runner.run([
        'configure-ai-agents',
        '--workspace',
        workspaceDir.path,
        '--no-interactive',
      ]);

      // Then check
      final checkBuffer = StringBuffer();
      final checkRunner = FxCommandRunner(outputSink: checkBuffer);
      await checkRunner.run([
        'configure-ai-agents',
        '--workspace',
        workspaceDir.path,
        '--check',
      ]);

      expect(checkBuffer.toString(), contains('up-to-date'));
    });

    test('--check detects stale configs', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);

      // Create a stale Claude config
      final claudeDir = Directory(
        p.join(workspaceDir.path, '.claude', 'rules'),
      );
      await claudeDir.create(recursive: true);
      await File(
        p.join(claudeDir.path, 'fx-workspace.md'),
      ).writeAsString('stale content');

      // Check should detect it's stale (throws ProcessExit)
      expect(
        () => runner.run([
          'configure-ai-agents',
          '--workspace',
          workspaceDir.path,
          '--check',
        ]),
        throwsA(isA<Exception>()),
      );
    });

    test('output reports which files were written', () async {
      final buffer = StringBuffer();
      final runner = FxCommandRunner(outputSink: buffer);
      await runner.run([
        'configure-ai-agents',
        '--workspace',
        workspaceDir.path,
        '--no-interactive',
      ]);

      final output = buffer.toString();
      expect(output, contains('claude'));
      expect(output, contains('cursor'));
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
