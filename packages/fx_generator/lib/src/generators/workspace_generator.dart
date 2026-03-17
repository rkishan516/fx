import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../generator.dart';

/// Workspace-level generators that modify existing code.

/// Adds a path dependency from one workspace package to another.
///
/// Usage: `fx generate add-dep source:target`
class AddDependencyGenerator extends Generator {
  @override
  String get name => 'add-dep';

  @override
  String get description => 'Add a path dependency between workspace packages.';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async {
    // name format: "source:target"
    final parts = context.projectName.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Expected format "source:target" (e.g., "app:core")');
    }

    final sourcePkg = parts[0];
    final targetPkg = parts[1];
    final sourcePubspec = p.join(
      context.outputDirectory,
      'packages',
      sourcePkg,
      'pubspec.yaml',
    );

    if (!File(sourcePubspec).existsSync()) {
      throw FileSystemException(
        'Source package pubspec not found',
        sourcePubspec,
      );
    }

    final content = File(sourcePubspec).readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;

    // Check if dependency already exists
    final deps = yaml['dependencies'] as YamlMap?;
    if (deps != null && deps.containsKey(targetPkg)) {
      return []; // Already exists
    }

    // Add the dependency
    String updated;
    if (content.contains('dependencies:')) {
      updated = content.replaceFirst(
        'dependencies:',
        'dependencies:\n  $targetPkg:\n    path: ../$targetPkg',
      );
    } else {
      updated =
          '$content\ndependencies:\n  $targetPkg:\n    path: ../$targetPkg\n';
    }

    return [
      GeneratedFile(
        relativePath: p.relative(sourcePubspec, from: context.outputDirectory),
        content: updated,
        overwrite: true,
      ),
    ];
  }
}

/// Renames a package across the workspace.
///
/// Usage: `fx generate rename old_name:new_name`
class RenamePackageGenerator extends Generator {
  @override
  String get name => 'rename';

  @override
  String get description => 'Rename a package across the workspace.';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async {
    final parts = context.projectName.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Expected format "old_name:new_name" (e.g., "utils:shared")',
      );
    }

    final oldName = parts[0];
    final newName = parts[1];
    final wsDir = context.outputDirectory;
    final results = <GeneratedFile>[];

    // Scan all pubspec.yaml files and update references
    final packagesDir = Directory(p.join(wsDir, 'packages'));
    if (packagesDir.existsSync()) {
      await for (final entity in packagesDir.list()) {
        if (entity is! Directory) continue;
        final pkgPubspec = File(p.join(entity.path, 'pubspec.yaml'));
        if (!pkgPubspec.existsSync()) continue;

        var content = pkgPubspec.readAsStringSync();
        if (content.contains(oldName)) {
          content = content.replaceAll('name: $oldName', 'name: $newName');
          content = content.replaceAll(
            'path: ../$oldName',
            'path: ../$newName',
          );
          results.add(
            GeneratedFile(
              relativePath: p.relative(pkgPubspec.path, from: wsDir),
              content: content,
              overwrite: true,
            ),
          );
        }
      }
    }

    return results;
  }
}

/// Moves a package to a different directory within the workspace.
///
/// Usage: `fx generate move pkg_name:libs`
class MovePackageGenerator extends Generator {
  @override
  String get name => 'move';

  @override
  String get description =>
      'Move a package to a different location in the workspace.';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async {
    // This generator operates at the file-system level and returns
    // instructions as GeneratedFile entries. The actual move is done
    // by the CLI command after confirming with the user.
    return [
      GeneratedFile(
        relativePath: '.fx_move_instructions.json',
        content:
            '{"package": "${context.projectName}", "destination": "${context.outputDirectory}"}',
      ),
    ];
  }
}
