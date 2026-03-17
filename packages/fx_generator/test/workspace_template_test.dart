import 'package:fx_generator/fx_generator.dart';
import 'package:test/test.dart';

void main() {
  group('WorkspaceTemplate', () {
    test('default template generates standard structure', () async {
      final template = WorkspaceTemplate.builtIn('default');
      expect(template, isNotNull);

      final files = await template!.generate('my_app');
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('pubspec.yaml'));
      expect(paths, contains('.gitignore'));
      expect(paths, contains('analysis_options.yaml'));
    });

    test(
      'fullstack template generates frontend and backend packages',
      () async {
        final template = WorkspaceTemplate.builtIn('fullstack');
        expect(template, isNotNull);

        final files = await template!.generate('my_app');
        final paths = files.map((f) => f.relativePath).toList();

        expect(paths, contains('pubspec.yaml'));
        expect(paths, contains('packages/frontend/pubspec.yaml'));
        expect(paths, contains('packages/backend/pubspec.yaml'));
        expect(paths, contains('packages/shared/pubspec.yaml'));
      },
    );

    test('plugin template generates plugin with example', () async {
      final template = WorkspaceTemplate.builtIn('plugin');
      expect(template, isNotNull);

      final files = await template!.generate('my_plugin');
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('pubspec.yaml'));
      expect(paths, contains('packages/my_plugin/pubspec.yaml'));
      expect(paths, contains('packages/my_plugin_example/pubspec.yaml'));
    });

    test('library template generates library with multiple packages', () async {
      final template = WorkspaceTemplate.builtIn('library');
      expect(template, isNotNull);

      final files = await template!.generate('utils');
      final paths = files.map((f) => f.relativePath).toList();

      expect(paths, contains('pubspec.yaml'));
      expect(paths, contains('packages/utils_core/pubspec.yaml'));
      expect(paths, contains('packages/utils/pubspec.yaml'));
    });

    test('builtIn returns null for unknown template', () {
      expect(WorkspaceTemplate.builtIn('nonexistent'), isNull);
    });

    test('availableTemplates lists all built-in templates', () {
      final templates = WorkspaceTemplate.availableTemplates;
      expect(
        templates,
        containsAll(['default', 'fullstack', 'plugin', 'library']),
      );
    });

    test('fullstack pubspec.yaml contains workspace members', () async {
      final template = WorkspaceTemplate.builtIn('fullstack');
      final files = await template!.generate('my_app');
      final pubspec = files.firstWhere((f) => f.relativePath == 'pubspec.yaml');

      expect(pubspec.content, contains('workspace:'));
      expect(pubspec.content, contains('packages/frontend'));
      expect(pubspec.content, contains('packages/backend'));
      expect(pubspec.content, contains('packages/shared'));
    });
  });
}
