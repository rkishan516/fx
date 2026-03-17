import 'dart:io';

import 'package:fx_generator/fx_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DartPackageGenerator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_gen_dart_pkg_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('name is dart_package', () {
      expect(DartPackageGenerator().name, equals('dart_package'));
    });

    test('has a description', () {
      expect(DartPackageGenerator().description, isNotEmpty);
    });

    test('generates expected files', () async {
      final gen = DartPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_package',
        outputDirectory: p.join(tempDir.path, 'my_package'),
        variables: {'description': 'A test package'},
      );

      final files = await gen.generate(ctx);
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('pubspec.yaml'));
      expect(paths, contains('analysis_options.yaml'));
      expect(paths, contains('lib/my_package.dart'));
      expect(paths, contains('lib/src/.gitkeep'));
      expect(paths, contains('test/my_package_test.dart'));
    });

    test('pubspec.yaml contains correct package name', () async {
      final gen = DartPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'awesome_lib',
        outputDirectory: p.join(tempDir.path, 'awesome_lib'),
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('name: awesome_lib'));
    });

    test('pubspec.yaml includes resolution: workspace', () async {
      final gen = DartPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_lib',
        outputDirectory: tempDir.path,
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('resolution: workspace'));
    });

    test('barrel export contains correct library name', () async {
      final gen = DartPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'cool_pkg',
        outputDirectory: tempDir.path,
        variables: {},
      );

      final files = await gen.generate(ctx);
      final barrel = files.firstWhere(
        (f) => f.relativePath == 'lib/cool_pkg.dart',
      );

      expect(barrel.content, contains('library cool_pkg'));
    });

    test(
      'all generated files have non-empty content except .gitkeep',
      () async {
        final gen = DartPackageGenerator();
        final ctx = GeneratorContext(
          projectName: 'pkg',
          outputDirectory: tempDir.path,
          variables: {},
        );

        final files = await gen.generate(ctx);
        for (final f in files) {
          if (!f.relativePath.endsWith('.gitkeep')) {
            expect(
              f.content,
              isNotEmpty,
              reason: '${f.relativePath} should not be empty',
            );
          }
        }
      },
    );
  });

  group('FlutterPackageGenerator', () {
    test('name is flutter_package', () {
      expect(FlutterPackageGenerator().name, equals('flutter_package'));
    });

    test('generates pubspec with flutter dependency', () async {
      final gen = FlutterPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_widget',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('flutter:'));
    });

    test('generates correct file structure', () async {
      final gen = FlutterPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_widget',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('pubspec.yaml'));
      expect(paths, contains('lib/my_widget.dart'));
    });

    test('pubspec contains package name', () async {
      final gen = FlutterPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'widgets_lib',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('name: widgets_lib'));
    });

    test('pubspec includes resolution: workspace', () async {
      final gen = FlutterPackageGenerator();
      final ctx = GeneratorContext(
        projectName: 'flutter_pkg',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('resolution: workspace'));
    });

    test('has a description', () {
      expect(FlutterPackageGenerator().description, isNotEmpty);
    });
  });

  group('FlutterAppGenerator', () {
    test('name is flutter_app', () {
      expect(FlutterAppGenerator().name, equals('flutter_app'));
    });

    test('generates lib/main.dart', () async {
      final gen = FlutterAppGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_app',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('lib/main.dart'));
    });

    test('generates complete file structure', () async {
      final gen = FlutterAppGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_app',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('pubspec.yaml'));
      expect(paths, contains('lib/main.dart'));
      expect(paths, contains('analysis_options.yaml'));
    });

    test('pubspec contains flutter sdk dependency', () async {
      final gen = FlutterAppGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_app',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('flutter:'));
      expect(pubspec.content, contains('name: my_app'));
    });

    test('main.dart contains runApp', () async {
      final gen = FlutterAppGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_app',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final main = files.firstWhere((f) => f.relativePath == 'lib/main.dart');

      expect(main.content, contains('runApp'));
    });

    test('has a description', () {
      expect(FlutterAppGenerator().description, isNotEmpty);
    });
  });

  group('DartCliGenerator', () {
    test('name is dart_cli', () {
      expect(DartCliGenerator().name, equals('dart_cli'));
    });

    test('generates bin/main.dart entry point', () async {
      final gen = DartCliGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_tool',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('bin/main.dart'));
    });

    test('pubspec includes args dependency', () async {
      final gen = DartCliGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_tool',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('args:'));
    });

    test('generates complete file structure', () async {
      final gen = DartCliGenerator();
      final ctx = GeneratorContext(
        projectName: 'cli_tool',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('pubspec.yaml'));
      expect(paths, contains('bin/main.dart'));
      expect(paths, contains('lib/cli_tool.dart'));
      expect(paths, contains('analysis_options.yaml'));
    });

    test('pubspec includes executables section', () async {
      final gen = DartCliGenerator();
      final ctx = GeneratorContext(
        projectName: 'my_tool',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('executables:'));
    });

    test('pubspec contains correct package name', () async {
      final gen = DartCliGenerator();
      final ctx = GeneratorContext(
        projectName: 'super_tool',
        outputDirectory: '/tmp/test',
        variables: {},
      );

      final files = await gen.generate(ctx);
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('name: super_tool'));
    });

    test('has a description', () {
      expect(DartCliGenerator().description, isNotEmpty);
    });
  });

  group('GeneratedFile', () {
    test('overwrite defaults correctly', () {
      final f = GeneratedFile(relativePath: 'test.dart', content: '// test');
      expect(f.relativePath, 'test.dart');
      expect(f.content, '// test');
    });
  });
}
