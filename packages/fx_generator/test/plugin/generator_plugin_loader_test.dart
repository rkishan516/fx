import 'dart:io';

import 'package:fx_generator/fx_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GeneratorPluginLoader', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_plugin_loader_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('returns empty list when no plugin directories configured', () async {
      final loader = GeneratorPluginLoader(pluginPaths: []);
      final generators = await loader.discover();
      expect(generators, isEmpty);
    });

    test('returns empty list when plugin directory does not exist', () async {
      final loader = GeneratorPluginLoader(
        pluginPaths: [p.join(tempDir.path, 'nonexistent')],
      );
      final generators = await loader.discover();
      expect(generators, isEmpty);
    });

    test('returns empty list when no valid plugins found', () async {
      // Create a directory that's not a valid plugin
      final dir = await Directory(
        p.join(tempDir.path, 'not_a_plugin'),
      ).create(recursive: true);
      await File(
        p.join(dir.path, 'random_file.txt'),
      ).writeAsString('not a plugin');

      final loader = GeneratorPluginLoader(pluginPaths: [tempDir.path]);
      final generators = await loader.discover();
      expect(generators, isEmpty);
    });

    test('discovers plugin package that has bin/generator.dart', () async {
      // Create a minimal plugin structure
      final pluginDir = await Directory(
        p.join(tempDir.path, 'my_generator_plugin'),
      ).create(recursive: true);
      final binDir = await Directory(p.join(pluginDir.path, 'bin')).create();

      // Write a minimal pubspec.yaml for the plugin
      await File(p.join(pluginDir.path, 'pubspec.yaml')).writeAsString('''
name: my_generator_plugin
version: 0.1.0
environment:
  sdk: ^3.11.1
dependencies:
  fx_generator:
    path: /fake/path
executables:
  generator: generator
''');

      // Write a stub bin/generator.dart
      await File(p.join(binDir.path, 'generator.dart')).writeAsString('''
import 'dart:io';
void main() { stdout.write('[]'); }
''');

      final loader = GeneratorPluginLoader(pluginPaths: [tempDir.path]);
      final generators = await loader.discover();

      // At least one plugin descriptor should be found
      expect(generators.length, greaterThanOrEqualTo(1));
    });

    test('PluginGenerator name comes from pubspec name', () async {
      final pluginDir = await Directory(
        p.join(tempDir.path, 'custom_gen'),
      ).create();
      final binDir = await Directory(p.join(pluginDir.path, 'bin')).create();

      await File(p.join(pluginDir.path, 'pubspec.yaml')).writeAsString('''
name: custom_gen
version: 0.1.0
environment:
  sdk: ^3.11.1
dependencies:
  fx_generator:
    path: /fake
executables:
  generator: generator
''');

      await File(
        p.join(binDir.path, 'generator.dart'),
      ).writeAsString('void main() {}');

      final loader = GeneratorPluginLoader(pluginPaths: [tempDir.path]);
      final generators = await loader.discover();

      expect(generators.any((g) => g.name == 'custom_gen'), isTrue);
    });
  });
}
