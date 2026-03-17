import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../output/output_formatter.dart';
import 'run_command.dart';

/// `fx sync` — Ensure workspace files are consistent and dependencies resolved.
///
/// `fx sync --check` — Check without modifying (for CI).
class SyncCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'sync';

  @override
  String get description =>
      'Ensure workspace consistency and resolve dependencies.';

  SyncCommand({required this.formatter, required this.processRunner}) {
    argParser.addFlag(
      'check',
      help: 'Check only, do not modify files (for CI).',
      negatable: false,
    );
  }

  /// Runs all workspace consistency checks. Returns the number of issues found.
  static Future<int> checkWorkspace(
    String root,
    OutputFormatter formatter,
  ) async {
    var issues = 0;
    final workspace = await WorkspaceLoader.load(root);
    final config = workspace.config;
    final pubspecs = FileUtils.findPubspecs(root, config.packages);

    for (final pubspecPath in pubspecs) {
      final content = File(pubspecPath).readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;
      final resolution = yaml['resolution']?.toString();
      if (resolution != 'workspace') {
        formatter.writeln(
          '  OUT OF SYNC: ${p.relative(pubspecPath, from: root)} '
          'missing resolution: workspace',
        );
        issues++;
      }
    }

    for (final project in workspace.projects) {
      final pubspecPath = p.join(project.path, 'pubspec.yaml');
      final content = File(pubspecPath).readAsStringSync();
      final yaml = loadYaml(content) as YamlMap;

      for (final section in ['dependencies', 'dev_dependencies']) {
        final deps = yaml[section];
        if (deps is! YamlMap) continue;
        for (final entry in deps.entries) {
          final val = entry.value;
          if (val is YamlMap && val.containsKey('path')) {
            final depPath = val['path'].toString();
            final resolved = p.normalize(p.join(project.path, depPath));
            if (!Directory(resolved).existsSync()) {
              formatter.writeln(
                '  BROKEN: ${project.name} depends on path "$depPath" '
                'which does not exist',
              );
              issues++;
            }
          }
        }
      }
    }

    final lockFile = File(p.join(root, 'pubspec.lock'));
    if (!lockFile.existsSync()) {
      formatter.writeln('  OUT OF SYNC: No pubspec.lock found');
      issues++;
    }

    return issues;
  }

  @override
  Future<void> run() async {
    final checkOnly = argResults!['check'] as bool;
    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }

    final issues = await checkWorkspace(root, formatter);

    if (issues > 0 && checkOnly) {
      formatter.writeln('\n$issues issue(s) found. Run `fx sync` to fix.');
      throw ProcessExit(1);
    }

    if (issues > 0 && !checkOnly) {
      // Run pub get to resolve
      formatter.writeln('\nResolving dependencies...');
      final result = await processRunner.run(
        ProcessCall(
          executable: 'dart',
          arguments: ['pub', 'get'],
          workingDirectory: root,
        ),
      );

      if (result.exitCode == 0) {
        formatter.writeln('Dependencies resolved successfully.');
      } else {
        formatter.writeln('Failed to resolve dependencies:');
        formatter.writeln(result.stderr);
      }
    }

    if (issues == 0) {
      formatter.writeln('Workspace is in sync. All checks passed.');
    }
  }
}
