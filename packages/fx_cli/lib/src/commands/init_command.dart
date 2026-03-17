import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_generator/fx_generator.dart';
import 'package:path/path.dart' as p;

/// `fx init` — Initializes a new fx workspace.
class InitCommand extends Command<void> {
  @override
  String get name => 'init';

  @override
  String get description =>
      'Initialize a new fx workspace in the current directory.';

  InitCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Workspace name.',
        defaultsTo: p.basename(Directory.current.path),
      )
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Directory to initialize workspace in.',
        defaultsTo: null,
      )
      ..addOption(
        'template',
        abbr: 't',
        help: 'Workspace template to use.',
        allowed: WorkspaceTemplate.availableTemplates,
        defaultsTo: null,
      );
  }

  @override
  Future<void> run() async {
    final name = argResults!['name'] as String;
    final dirArg = argResults!['dir'] as String?;
    final templateName = argResults!['template'] as String?;
    final targetDir = dirArg != null ? Directory(dirArg) : Directory.current;

    if (templateName != null) {
      await _initFromTemplate(name, targetDir.path, templateName);
    } else {
      await _initWorkspace(name, targetDir.path);
    }
    Logger.success('Workspace "$name" initialized at ${targetDir.path}');
  }

  Future<void> _initFromTemplate(
    String name,
    String dir,
    String templateName,
  ) async {
    final template = WorkspaceTemplate.builtIn(templateName);
    if (template == null) {
      return; // Should not happen due to argParser validation
    }

    final files = await template.generate(name);
    for (final file in files) {
      final fullPath = p.join(dir, file.relativePath);
      FileUtils.ensureDir(p.dirname(fullPath));
      FileUtils.writeFile(fullPath, file.content);
    }
  }

  Future<void> _initWorkspace(String name, String dir) async {
    FileUtils.ensureDir(dir);
    FileUtils.ensureDir(p.join(dir, 'packages'));
    FileUtils.ensureDir(p.join(dir, 'apps'));

    FileUtils.writeFile(p.join(dir, 'pubspec.yaml'), _rootPubspec(name));
    FileUtils.writeFile(p.join(dir, 'analysis_options.yaml'), _analysisOptions);
    FileUtils.writeFile(p.join(dir, '.gitignore'), _gitignore);
  }

  String _rootPubspec(String name) =>
      '''
name: ${name}_workspace
description: "$name — fx managed monorepo workspace."
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/*
  - apps/*

fx:
  packages:
    - packages/*
    - apps/*
  targets:
    test:
      executor: dart test
      inputs:
        - lib/**
        - test/**
    analyze:
      executor: dart analyze
      inputs:
        - lib/**
    format:
      executor: dart format .
      inputs:
        - lib/**
        - test/**
  cache:
    enabled: true
    directory: .fx_cache
''';

  static const _analysisOptions = '''
include: package:lints/recommended.yaml
''';

  static const _gitignore = '''
.dart_tool/
.fx_cache/
build/
''';
}
