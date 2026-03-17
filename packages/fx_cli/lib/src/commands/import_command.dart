import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'package:fx_runner/fx_runner.dart';

import '../output/output_formatter.dart';

/// `fx import <path|url>` — Import an external package into the workspace.
///
/// Attempts to use `git subtree add` to preserve git history. Falls back
/// to plain file copy if the source is not a git repository.
class ImportCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'import';

  @override
  String get description =>
      'Import an external Dart/Flutter package into the workspace.\n'
      'Preserves git history via git subtree when possible.';

  ImportCommand({required this.formatter, ProcessRunner? processRunner})
    : processRunner = processRunner ?? const SystemProcessRunner() {
    argParser
      ..addOption(
        'directory',
        abbr: 'd',
        help: 'Destination directory within the workspace (default: packages).',
        defaultsTo: 'packages',
      )
      ..addOption(
        'branch',
        help: 'Branch to import from (for git repos).',
        defaultsTo: 'main',
      )
      ..addOption(
        'source-directory',
        help:
            'Subdirectory within the source repo to import (for monorepo imports).',
      )
      ..addOption(
        'depth',
        help: 'Git clone depth (shallow clone for faster import).',
      )
      ..addFlag(
        'no-history',
        help: 'Skip git history, just copy files.',
        negatable: false,
      );
  }

  @override
  Future<void> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      throw UsageException(
        'Provide the path or URL to the package to import.',
        usage,
      );
    }

    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }

    final source = args.first;
    final sourceSubdir = argResults!['source-directory'] as String?;
    final depthArg = argResults!['depth'] as String?;
    final isUrl =
        source.startsWith('http') ||
        source.startsWith('git@') ||
        source.contains('.git');

    String sourcePath;
    String? tempCloneDir;

    if (isUrl) {
      // Clone the repo to a temp directory first
      tempCloneDir = p.join(root, '.fx_tmp_import');
      await Directory(tempCloneDir).create(recursive: true);

      final cloneArgs = ['clone'];
      if (depthArg != null) {
        cloneArgs.addAll(['--depth', depthArg]);
      }
      final branch = argResults!['branch'] as String;
      cloneArgs.addAll(['--branch', branch, source, tempCloneDir]);

      formatter.writeln('Cloning $source...');
      final cloneResult = await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: cloneArgs,
          workingDirectory: root,
        ),
      );
      if (cloneResult.exitCode != 0) {
        await Directory(tempCloneDir).delete(recursive: true);
        throw UsageException('Failed to clone: ${cloneResult.stderr}', usage);
      }

      sourcePath = sourceSubdir != null
          ? p.join(tempCloneDir, sourceSubdir)
          : tempCloneDir;
    } else {
      sourcePath = p.normalize(p.absolute(source));
      if (sourceSubdir != null) {
        sourcePath = p.join(sourcePath, sourceSubdir);
      }
    }

    final sourceDir = Directory(sourcePath);
    if (!sourceDir.existsSync()) {
      if (tempCloneDir != null) {
        await Directory(tempCloneDir).delete(recursive: true);
      }
      throw UsageException('Source path does not exist: $sourcePath', usage);
    }

    final sourcePubspec = File(p.join(sourcePath, 'pubspec.yaml'));
    if (!sourcePubspec.existsSync()) {
      if (tempCloneDir != null) {
        await Directory(tempCloneDir).delete(recursive: true);
      }
      throw UsageException(
        'Source path is not a Dart package (no pubspec.yaml).',
        usage,
      );
    }

    // Read package name from source pubspec
    final sourceContent = sourcePubspec.readAsStringSync();
    final sourceYaml = loadYaml(sourceContent) as YamlMap;
    final packageName = sourceYaml['name']?.toString();
    if (packageName == null || packageName.isEmpty) {
      if (tempCloneDir != null) {
        await Directory(tempCloneDir).delete(recursive: true);
      }
      throw UsageException('Source pubspec.yaml has no name field.', usage);
    }

    final destSubdir = argResults!['directory'] as String;
    final destPath = p.join(root, destSubdir, packageName);

    if (Directory(destPath).existsSync()) {
      if (tempCloneDir != null) {
        await Directory(tempCloneDir).delete(recursive: true);
      }
      throw UsageException(
        'Destination already exists: ${p.relative(destPath, from: root)}',
        usage,
      );
    }

    final noHistory = argResults!['no-history'] as bool;
    final branch = argResults!['branch'] as String;
    final destRelative = p.join(destSubdir, packageName);

    formatter.writeln('Importing "$packageName" into $destSubdir/...');

    var usedSubtree = false;
    if (!noHistory) {
      usedSubtree = await _trySubtreeImport(
        root: root,
        sourcePath: sourcePath,
        destRelative: destRelative,
        branch: branch,
      );
    }

    if (!usedSubtree) {
      _copyDirectory(sourceDir, Directory(destPath));
    }

    // Ensure resolution: workspace in the imported pubspec
    final destPubspec = File(p.join(destPath, 'pubspec.yaml'));
    if (destPubspec.existsSync()) {
      final destContent = destPubspec.readAsStringSync();
      final destYaml = loadYaml(destContent) as YamlMap;
      if (destYaml['resolution']?.toString() != 'workspace') {
        final editor = YamlEditor(destContent);
        editor.update(['resolution'], 'workspace');
        destPubspec.writeAsStringSync(editor.toString());
      }
    }

    // Clean up temp clone directory
    if (tempCloneDir != null) {
      await Directory(tempCloneDir).delete(recursive: true);
    }

    final method = usedSubtree ? ' (with git history)' : '';
    formatter.writeln(
      'Imported "$packageName" to ${p.relative(destPath, from: root)}$method.',
    );
  }

  /// Attempts to import via `git subtree add`. Returns true on success.
  Future<bool> _trySubtreeImport({
    required String root,
    required String sourcePath,
    required String destRelative,
    required String branch,
  }) async {
    // Check if source is a git repo
    final sourceGit = Directory(p.join(sourcePath, '.git'));
    if (!sourceGit.existsSync()) return false;

    // Check if workspace is a git repo
    final workspaceGit = Directory(p.join(root, '.git'));
    if (!workspaceGit.existsSync()) return false;

    try {
      final result = await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: [
            'subtree',
            'add',
            '--prefix=$destRelative',
            sourcePath,
            branch,
            '--squash',
          ],
          workingDirectory: root,
        ),
      );

      if (result.exitCode == 0) {
        formatter.writeln('Git history preserved via subtree.');
        return true;
      }
    } catch (_) {
      // Subtree not available or failed — fall back to copy
    }
    return false;
  }

  void _copyDirectory(Directory source, Directory destination) {
    destination.createSync(recursive: true);
    for (final entity in source.listSync()) {
      final name = p.basename(entity.path);
      // Skip hidden files, build artifacts, and .dart_tool
      if (name.startsWith('.') || name == 'build' || name == '.dart_tool') {
        continue;
      }
      final destPath = p.join(destination.path, name);
      if (entity is Directory) {
        _copyDirectory(entity, Directory(destPath));
      } else if (entity is File) {
        entity.copySync(destPath);
      }
    }
  }
}
