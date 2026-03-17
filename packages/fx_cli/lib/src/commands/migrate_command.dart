import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../output/output_formatter.dart';

/// Parsed melos.yaml configuration.
class MelosConfig {
  final String name;
  final List<String> packages;
  final Map<String, String> scripts;

  const MelosConfig({
    required this.name,
    required this.packages,
    required this.scripts,
  });

  factory MelosConfig.parse(String content) {
    final yaml = loadYaml(content) as YamlMap;
    final name = yaml['name']?.toString() ?? '';

    final pkgsRaw = yaml['packages'] as YamlList?;
    final packages = pkgsRaw?.map((e) => e.toString()).toList() ?? <String>[];

    final scriptsRaw = yaml['scripts'];
    final scripts = <String, String>{};
    if (scriptsRaw is YamlMap) {
      for (final entry in scriptsRaw.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is String) {
          scripts[key] = val;
        } else if (val is YamlMap) {
          final run = val['run'];
          if (run is String) scripts[key] = run;
        }
      }
    }

    return MelosConfig(name: name, packages: packages, scripts: scripts);
  }
}

/// `fx migrate` — Converts a melos workspace to fx.
class MigrateCommand extends Command<void> {
  final OutputFormatter formatter;
  final MigrationRegistry _registry;

  @override
  String get name => 'migrate';

  @override
  String get description => 'Convert a melos workspace to fx configuration.';

  MigrateCommand({
    required this.formatter,
    MigrationRegistry? migrationRegistry,
  }) : _registry = migrationRegistry ?? MigrationRegistry() {
    argParser
      ..addOption(
        'dir',
        abbr: 'd',
        help: 'Directory of the melos workspace.',
        defaultsTo: null,
      )
      ..addFlag(
        'version-update',
        help: 'Update fx config to latest format version.',
        negatable: false,
      )
      ..addFlag(
        'interactive',
        help: 'Interactively select migrations to apply.',
        negatable: false,
      )
      ..addOption(
        'update-deps',
        help: 'Update a dependency across all packages (name:version).',
      )
      ..addFlag(
        'dry-run',
        help: 'Preview changes without writing files.',
        negatable: false,
      )
      ..addFlag(
        'json',
        help: 'Output in JSON format (for editor integrations).',
        negatable: false,
      )
      ..addFlag(
        'list',
        help: 'List available plugin migrations.',
        negatable: false,
      )
      ..addOption(
        'plugin',
        help: 'Plugin name to filter or run migrations for.',
      )
      ..addOption('from', help: 'Current plugin version (used with --plugin).')
      ..addOption('to', help: 'Target plugin version (used with --plugin).');
  }

  @override
  Future<void> run() async {
    final listFlag = argResults!['list'] as bool;
    if (listFlag) {
      _listMigrations();
      return;
    }

    final pluginName = argResults!['plugin'] as String?;
    if (pluginName != null) {
      await _runPluginMigrations(pluginName);
      return;
    }

    final versionUpdate = argResults!['version-update'] as bool;
    if (versionUpdate) {
      await _versionUpdate();
      return;
    }

    final updateDeps = argResults!['update-deps'] as String?;
    if (updateDeps != null) {
      await _updateDependency(updateDeps);
      return;
    }

    final dirArg = argResults!['dir'] as String?;
    final dir = dirArg ?? Directory.current.path;

    final melosFile = File(p.join(dir, 'melos.yaml'));
    if (!melosFile.existsSync()) {
      throw FxException(
        'No melos.yaml found at $dir',
        hint: 'Run this command from a melos workspace root.',
      );
    }

    final melosContent = melosFile.readAsStringSync();
    final melosConfig = MelosConfig.parse(melosContent);

    // Convert melos packages patterns: melos uses ** for recursive,
    // fx uses * for single-level glob
    final fxPackages = melosConfig.packages
        .map((p) => p.replaceAll('/**', '/*'))
        .toList();

    // Build fx targets from melos scripts
    final targets = <String, Map<String, dynamic>>{};
    for (final entry in melosConfig.scripts.entries) {
      targets[entry.key] = {'executor': entry.value};
    }

    // Update pubspec.yaml with fx: section
    final pubspecFile = File(p.join(dir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      throw FxException(
        'No pubspec.yaml found at $dir',
        hint: 'The workspace must have a pubspec.yaml.',
      );
    }

    final pubspecContent = pubspecFile.readAsStringSync();
    final editor = YamlEditor(pubspecContent);

    // Add fx: section
    final fxSection = <String, dynamic>{
      'packages': fxPackages,
      'targets': targets,
      'cache': {'enabled': true, 'directory': '.fx_cache'},
    };

    editor.update(['fx'], fxSection);

    // Add workspace: section if not present
    final yaml = loadYaml(pubspecContent) as YamlMap;
    if (!yaml.containsKey('workspace')) {
      editor.update(['workspace'], fxPackages);
    }

    pubspecFile.writeAsStringSync(editor.toString());

    formatter.write('Migration complete!\n');
    formatter.write(
      '  Converted ${melosConfig.scripts.length} melos scripts '
      'to fx targets.\n',
    );
    formatter.write('  Package patterns: ${fxPackages.join(', ')}\n');
    formatter.write('\nYou can now use fx commands instead of melos.\n');
    formatter.write('Run `fx bootstrap` to install dependencies.\n');
  }

  /// Lists all migrations available in the registry, optionally filtered by plugin name.
  void _listMigrations() {
    final filterPlugin = argResults!['plugin'] as String?;
    final jsonFlag = argResults!['json'] as bool;
    final migrations = _registry.all.where((m) {
      if (filterPlugin != null) return m.pluginName == filterPlugin;
      return true;
    }).toList();

    if (jsonFlag) {
      final data = migrations
          .map(
            (m) => {
              'pluginName': m.pluginName,
              'fromVersion': m.fromVersion,
              'toVersion': m.toVersion,
            },
          )
          .toList();
      formatter.writeln(jsonEncode(data));
      return;
    }

    if (migrations.isEmpty) {
      formatter.writeln('No migrations registered.');
      return;
    }

    formatter.writeln('Available migrations:');
    for (final m in migrations) {
      formatter.writeln('  ${m.pluginName}  ${m.fromVersion} → ${m.toVersion}');
    }
  }

  /// Runs plugin migrations from [pluginName] between --from and --to versions.
  Future<void> _runPluginMigrations(String pluginName) async {
    final fromVersion = argResults!['from'] as String?;
    final toVersion = argResults!['to'] as String?;
    final dryRun = argResults!['dry-run'] as bool;
    final jsonFlag = argResults!['json'] as bool;

    if (fromVersion == null || toVersion == null) {
      throw FxException(
        'Both --from and --to are required when using --plugin.',
        hint: 'Example: fx migrate --plugin my_plugin --from 1.0.0 --to 2.0.0',
      );
    }

    final migrations = _registry.findMigrations(
      pluginName: pluginName,
      currentVersion: fromVersion,
      targetVersion: toVersion,
    );

    if (migrations.isEmpty) {
      if (jsonFlag) {
        formatter.writeln(jsonEncode([]));
      } else {
        formatter.writeln(
          'No migrations found for $pluginName ($fromVersion → $toVersion).',
        );
      }
      return;
    }

    final root =
        FileUtils.findWorkspaceRoot(Directory.current.path) ??
        Directory.current.path;

    if (!jsonFlag) {
      formatter.writeln(
        'Running $pluginName migrations '
        '($fromVersion → $toVersion)...',
      );
    }

    final jsonSteps = <Map<String, dynamic>>[];
    for (final migration in migrations) {
      final changes = await migration.prepare(root);

      if (jsonFlag) {
        jsonSteps.add({
          'pluginName': migration.pluginName,
          'fromVersion': migration.fromVersion,
          'toVersion': migration.toVersion,
          'changes': changes
              .map(
                (c) => {
                  'type': c.type.name,
                  'filePath': c.filePath,
                  'description': c.description,
                },
              )
              .toList(),
        });
      } else if (dryRun) {
        formatter.writeln(
          '\n[dry-run] ${migration.pluginName} ${migration.fromVersion} → ${migration.toVersion}',
        );
        if (changes.isEmpty) {
          formatter.writeln('  No changes required.');
        } else {
          for (final change in changes) {
            formatter.writeln('  ${change.type.name}: ${change.filePath}');
            if (change.description.isNotEmpty) {
              formatter.writeln('    ${change.description}');
            }
          }
        }
      } else {
        await migration.execute(root, changes);
        formatter.writeln(
          '  Applied: ${migration.pluginName} ${migration.fromVersion} → ${migration.toVersion}',
        );
      }
    }

    if (jsonFlag) {
      formatter.writeln(jsonEncode(jsonSteps));
    } else if (!dryRun) {
      formatter.writeln(
        '\nApplied ${migrations.length} migration(s) for $pluginName.',
      );
    }
  }

  /// Updates a dependency version across all workspace packages.
  ///
  /// [spec] format: `package_name:version_constraint` (e.g., `http:^1.2.0`)
  Future<void> _updateDependency(String spec) async {
    final parts = spec.split(':');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw FxException(
        'Invalid format: "$spec". Use name:version (e.g., http:^1.2.0)',
      );
    }
    final pkgName = parts[0];
    final newVersion = parts[1];
    final dryRun = argResults!['dry-run'] as bool;

    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw FxException(
        'Not inside an fx workspace.',
        hint: 'Run this command from a workspace root.',
      );
    }

    final workspace = await WorkspaceLoader.load(root);
    var updated = 0;

    for (final project in workspace.projects) {
      final pubspecFile = File(p.join(project.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) continue;
      final content = pubspecFile.readAsStringSync();

      // Check if the package is listed as a dependency
      final yaml = loadYaml(content) as YamlMap;
      var found = false;
      for (final section in ['dependencies', 'dev_dependencies']) {
        final deps = yaml[section];
        if (deps is YamlMap && deps.containsKey(pkgName)) {
          found = true;
          break;
        }
      }
      if (!found) continue;

      final editor = YamlEditor(content);
      // Update in dependencies or dev_dependencies
      for (final section in ['dependencies', 'dev_dependencies']) {
        final deps = yaml[section];
        if (deps is YamlMap && deps.containsKey(pkgName)) {
          editor.update([section, pkgName], newVersion);
        }
      }

      if (dryRun) {
        formatter.writeln(
          '  Would update $pkgName to $newVersion in ${project.name}',
        );
      } else {
        pubspecFile.writeAsStringSync(editor.toString());
        formatter.writeln(
          '  Updated $pkgName to $newVersion in ${project.name}',
        );
      }
      updated++;
    }

    if (updated == 0) {
      formatter.writeln('No packages depend on "$pkgName".');
    } else {
      final verb = dryRun ? 'Would update' : 'Updated';
      formatter.writeln('\n$verb $pkgName in $updated package(s).');
      if (!dryRun) {
        formatter.writeln('Run `dart pub get` to apply changes.');
      }
    }
  }

  Future<void> _versionUpdate() async {
    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw FxException(
        'Not inside an fx workspace.',
        hint: 'Run this command from a workspace root.',
      );
    }

    var applied = 0;

    // Migration 1: Ensure targetDefaults section exists
    final fxYamlFile = File(p.join(root, 'fx.yaml'));
    if (fxYamlFile.existsSync()) {
      final content = fxYamlFile.readAsStringSync();
      if (!content.contains('targetDefaults')) {
        final editor = YamlEditor(content);
        editor.update(['targetDefaults'], {});
        fxYamlFile.writeAsStringSync(editor.toString());
        formatter.writeln('Added targetDefaults section to fx.yaml');
        applied++;
      }
      if (!content.contains('namedInputs')) {
        final editor = YamlEditor(fxYamlFile.readAsStringSync());
        editor.update(
          ['namedInputs'],
          {
            'default': ['lib/**', 'test/**'],
          },
        );
        fxYamlFile.writeAsStringSync(editor.toString());
        formatter.writeln('Added namedInputs with default patterns');
        applied++;
      }
      if (!content.contains('defaultBase')) {
        final editor = YamlEditor(fxYamlFile.readAsStringSync());
        editor.update(['defaultBase'], 'main');
        fxYamlFile.writeAsStringSync(editor.toString());
        formatter.writeln('Added defaultBase setting');
        applied++;
      }
    }

    // Migration 2: Ensure all packages have resolution: workspace
    final workspace = await WorkspaceLoader.load(root);
    for (final project in workspace.projects) {
      final pubspecFile = File(p.join(project.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) continue;
      final content = pubspecFile.readAsStringSync();
      if (!content.contains('resolution: workspace')) {
        final editor = YamlEditor(content);
        editor.update(['resolution'], 'workspace');
        pubspecFile.writeAsStringSync(editor.toString());
        formatter.writeln('Added resolution: workspace to ${project.name}');
        applied++;
      }
    }

    if (applied == 0) {
      formatter.writeln('Already up to date. No migrations needed.');
    } else {
      formatter.writeln('\nApplied $applied migration(s).');
    }
  }
}
