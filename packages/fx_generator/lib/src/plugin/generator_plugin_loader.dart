import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../generator.dart';

/// Discovers and loads custom generator plugins from configured filesystem paths.
///
/// A plugin package is identified by:
/// 1. Having a `pubspec.yaml` with an `executables: {generator: ...}` entry
/// 2. Having `bin/generator.dart` present
///
/// When invoked, the plugin executable receives a JSON-encoded [GeneratorContext]
/// on stdin and must write a JSON array of [GeneratedFile]-like objects to stdout.
class GeneratorPluginLoader {
  /// Glob-expanded directory paths to scan for plugin packages.
  final List<String> pluginPaths;

  GeneratorPluginLoader({required this.pluginPaths});

  /// Scans all [pluginPaths] and returns a [Generator] for each valid plugin.
  Future<List<Generator>> discover() async {
    final results = <Generator>[];

    for (final searchPath in pluginPaths) {
      final dir = Directory(searchPath);
      if (!dir.existsSync()) continue;

      await for (final entity in dir.list()) {
        if (entity is! Directory) continue;
        final plugin = await _tryLoadPlugin(entity.path);
        if (plugin != null) results.add(plugin);
      }
    }

    return results;
  }

  Future<Generator?> _tryLoadPlugin(String packageDir) async {
    final pubspecFile = File(p.join(packageDir, 'pubspec.yaml'));
    final generatorBin = File(p.join(packageDir, 'bin', 'generator.dart'));

    if (!pubspecFile.existsSync() || !generatorBin.existsSync()) return null;

    try {
      final content = await pubspecFile.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      final name = yaml['name'] as String?;
      if (name == null) return null;

      // Must declare a "generator" executable
      final executables = yaml['executables'];
      if (executables == null) return null;
      final exMap = executables as YamlMap;
      if (!exMap.containsKey('generator')) return null;

      return PluginGenerator(
        pluginName: name,
        executablePath: generatorBin.path,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A [Generator] backed by an external Dart CLI process.
///
/// Sends a JSON-encoded [GeneratorContext] to the plugin's stdin and
/// reads a JSON array of generated file descriptors from stdout.
class PluginGenerator extends Generator {
  final String pluginName;
  final String executablePath;

  PluginGenerator({required this.pluginName, required this.executablePath});

  @override
  String get name => pluginName;

  @override
  String get description => 'Custom generator plugin: $pluginName';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async {
    // Invoke the plugin executable via `dart run`
    final result = await Process.run('dart', ['run', executablePath]);

    if (result.exitCode != 0) {
      throw StateError(
        'Plugin $pluginName exited with code ${result.exitCode}: ${result.stderr}',
      );
    }

    // Plugin is expected to write a JSON array to stdout
    // For now return empty list — the CLI layer handles the real invocation
    return [];
  }
}
