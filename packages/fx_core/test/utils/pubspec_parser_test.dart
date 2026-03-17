import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('PubspecParser', () {
    test('parses name from pubspec content', () {
      const content = '''
name: my_package
version: 1.0.0
environment:
  sdk: ^3.0.0
''';
      final result = PubspecParser.parse(content, path: '/fake/pubspec.yaml');
      expect(result.name, 'my_package');
    });

    test('parses path dependencies', () {
      const content = '''
name: app
dependencies:
  core:
    path: ../core
  utils:
    path: ../../utils
  http: ^1.0.0
''';
      final result = PubspecParser.parse(content, path: '/fake/pubspec.yaml');
      expect(result.pathDependencies, hasLength(2));
      expect(result.pathDependencies['core'], '../core');
      expect(result.pathDependencies['utils'], '../../utils');
    });

    test('returns empty pathDependencies when no path deps', () {
      const content = '''
name: simple
dependencies:
  test: ^1.0.0
''';
      final result = PubspecParser.parse(content, path: '/fake/pubspec.yaml');
      expect(result.pathDependencies, isEmpty);
    });

    test('detects flutter dependency', () {
      const content = '''
name: flutter_app
dependencies:
  flutter:
    sdk: flutter
''';
      final result = PubspecParser.parse(content, path: '/fake/pubspec.yaml');
      expect(result.hasFlutterDependency, isTrue);
    });

    test('no flutter dependency returns false', () {
      const content = '''
name: dart_lib
dependencies:
  path: ^1.8.0
''';
      final result = PubspecParser.parse(content, path: '/fake/pubspec.yaml');
      expect(result.hasFlutterDependency, isFalse);
    });

    test('has fx section', () {
      const content = '''
name: root
fx:
  packages:
    - packages/*
''';
      final result = PubspecParser.parse(content, path: '/fake/pubspec.yaml');
      expect(result.hasFxSection, isTrue);
    });

    test('throws on malformed YAML', () {
      const content = '''
name: bad
  - invalid: yaml: here
''';
      expect(
        () => PubspecParser.parse(content, path: '/bad/pubspec.yaml'),
        throwsA(isA<FxException>()),
      );
    });

    test('parses workspace members', () {
      const content = '''
name: root
workspace:
  - packages/fx_core
  - packages/fx_cli
''';
      final result = PubspecParser.parse(content, path: '/root/pubspec.yaml');
      expect(
        result.workspaceMembers,
        containsAll(['packages/fx_core', 'packages/fx_cli']),
      );
    });
  });
}
