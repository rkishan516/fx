import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fx_discovery_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('ProjectDiscovery', () {
    test('discovers dart package', () async {
      _createPackage(tempDir.path, 'packages/my_lib', '''
name: my_lib
version: 1.0.0
environment:
  sdk: ^3.11.1
''');

      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      expect(projects, hasLength(1));
      expect(projects.first.name, 'my_lib');
      expect(projects.first.type, ProjectType.dartPackage);
    });

    test('discovers flutter app vs flutter package', () async {
      // Flutter app has lib/main.dart
      _createPackage(tempDir.path, 'apps/my_app', '''
name: my_app
environment:
  sdk: ^3.11.1
dependencies:
  flutter:
    sdk: flutter
''');
      File(p.join(tempDir.path, 'apps/my_app/lib/main.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('void main() {}');

      // Flutter package has no lib/main.dart
      _createPackage(tempDir.path, 'packages/my_widget', '''
name: my_widget
environment:
  sdk: ^3.11.1
dependencies:
  flutter:
    sdk: flutter
''');

      final config = FxConfig.fromYaml({
        'packages': ['apps/*', 'packages/*'],
      });
      final projects = await ProjectDiscovery.discover(tempDir.path, config);
      projects.sort((a, b) => a.name.compareTo(b.name));

      expect(projects, hasLength(2));
      final app = projects.firstWhere((p) => p.name == 'my_app');
      final widget = projects.firstWhere((p) => p.name == 'my_widget');
      expect(app.type, ProjectType.flutterApp);
      expect(widget.type, ProjectType.flutterPackage);
    });

    test('discovers dart CLI package (has bin/ directory)', () async {
      _createPackage(tempDir.path, 'tools/my_cli', '''
name: my_cli
environment:
  sdk: ^3.11.1
''');
      Directory(
        p.join(tempDir.path, 'tools/my_cli/bin'),
      ).createSync(recursive: true);

      final config = FxConfig.fromYaml({
        'packages': ['tools/*'],
      });
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      expect(projects.first.type, ProjectType.dartCli);
    });

    test('extracts path dependencies', () async {
      _createPackage(tempDir.path, 'packages/core', '''
name: core
environment:
  sdk: ^3.11.1
''');
      _createPackage(tempDir.path, 'packages/app', '''
name: app
environment:
  sdk: ^3.11.1
dependencies:
  core:
    path: ../core
''');

      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      final projects = await ProjectDiscovery.discover(tempDir.path, config);
      final app = projects.firstWhere((p) => p.name == 'app');

      expect(app.dependencies, contains('core'));
    });

    test('returns empty list when no packages match pattern', () async {
      final config = FxConfig.fromYaml({
        'packages': ['nonexistent/*'],
      });
      final projects = await ProjectDiscovery.discover(tempDir.path, config);
      expect(projects, isEmpty);
    });

    test('respects .fxignore to exclude projects', () async {
      _createPackage(tempDir.path, 'packages/keep_me', '''
name: keep_me
version: 1.0.0
environment:
  sdk: ^3.11.1
''');
      _createPackage(tempDir.path, 'packages/legacy_auth', '''
name: legacy_auth
version: 1.0.0
environment:
  sdk: ^3.11.1
''');

      // Create .fxignore
      File(
        p.join(tempDir.path, '.fxignore'),
      ).writeAsStringSync('packages/legacy_*\n');

      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      expect(projects, hasLength(1));
      expect(projects.first.name, 'keep_me');
    });

    test('discovers all projects when .fxignore is absent', () async {
      _createPackage(tempDir.path, 'packages/pkg_a', '''
name: pkg_a
version: 1.0.0
environment:
  sdk: ^3.11.1
''');
      _createPackage(tempDir.path, 'packages/pkg_b', '''
name: pkg_b
version: 1.0.0
environment:
  sdk: ^3.11.1
''');

      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      final projects = await ProjectDiscovery.discover(tempDir.path, config);

      expect(projects, hasLength(2));
    });

    test('errors on duplicate package names', () async {
      _createPackage(tempDir.path, 'pkgs_a/lib', '''
name: shared_lib
environment:
  sdk: ^3.11.1
''');
      _createPackage(tempDir.path, 'pkgs_b/lib', '''
name: shared_lib
environment:
  sdk: ^3.11.1
''');

      final config = FxConfig.fromYaml({
        'packages': ['pkgs_a/*', 'pkgs_b/*'],
      });
      expect(
        () => ProjectDiscovery.discover(tempDir.path, config),
        throwsA(isA<FxException>()),
      );
    });
  });
}

void _createPackage(String root, String relPath, String pubspecContent) {
  final dir = Directory(p.join(root, relPath));
  dir.createSync(recursive: true);
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(pubspecContent);
}
