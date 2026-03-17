import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ImportAnalyzer', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('import_analyzer_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('extracts package imports from Dart files', () async {
      final libDir = Directory(p.join(tempDir.path, 'lib'));
      await libDir.create();

      await File(p.join(libDir.path, 'main.dart')).writeAsString('''
import 'package:core/core.dart';
import 'package:utils/utils.dart';
import 'dart:io';

void main() {}
''');

      final analysis = await ImportAnalyzer.analyze(tempDir.path);

      expect(analysis.fileImports, hasLength(1));
      expect(
        analysis.fileImports['lib/main.dart'],
        containsAll(['core', 'utils']),
      );
      // dart:io is not a package import
      expect(analysis.fileImports['lib/main.dart'], isNot(contains('io')));
    });

    test('handles files with no imports', () async {
      final libDir = Directory(p.join(tempDir.path, 'lib'));
      await libDir.create();

      await File(
        p.join(libDir.path, 'empty.dart'),
      ).writeAsString('void main() {}\n');

      final analysis = await ImportAnalyzer.analyze(tempDir.path);
      expect(analysis.fileImports, isEmpty);
    });

    test('tracks packageImporters correctly', () async {
      final libDir = Directory(p.join(tempDir.path, 'lib'));
      final srcDir = Directory(p.join(libDir.path, 'src'));
      await srcDir.create(recursive: true);

      await File(
        p.join(libDir.path, 'a.dart'),
      ).writeAsString("import 'package:shared/shared.dart';");
      await File(
        p.join(srcDir.path, 'b.dart'),
      ).writeAsString("import 'package:shared/shared.dart';");

      final analysis = await ImportAnalyzer.analyze(tempDir.path);

      expect(analysis.packageImporters['shared'], hasLength(2));
    });

    test('returns empty analysis when no lib/ directory', () async {
      final analysis = await ImportAnalyzer.analyze(tempDir.path);
      expect(analysis.fileImports, isEmpty);
      expect(analysis.packageImporters, isEmpty);
    });
  });

  group('ImportAnalyzer.detectImplicitDependencies', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('implicit_deps_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Project makeProject(String name, {List<String> deps = const []}) => Project(
      name: name,
      path: p.join(tempDir.path, name),
      type: ProjectType.dartPackage,
      dependencies: deps,
      targets: {},
      tags: [],
    );

    test('detects workspace import not declared in pubspec', () async {
      // Create project "app" that imports "utils" without declaring it
      final appLib = Directory(p.join(tempDir.path, 'app', 'lib'));
      await appLib.create(recursive: true);
      await File(p.join(appLib.path, 'main.dart')).writeAsString('''
import 'package:utils/utils.dart';
void main() {}
''');

      // Create project "utils"
      final utilsLib = Directory(p.join(tempDir.path, 'utils', 'lib'));
      await utilsLib.create(recursive: true);

      final app = makeProject('app');
      final utils = makeProject('utils');

      final implicit = await ImportAnalyzer.detectImplicitDependencies(
        project: app,
        allProjects: [app, utils],
      );

      expect(implicit, ['utils']);
    });

    test('does not flag declared dependencies', () async {
      final appLib = Directory(p.join(tempDir.path, 'app', 'lib'));
      await appLib.create(recursive: true);
      await File(p.join(appLib.path, 'main.dart')).writeAsString('''
import 'package:core/core.dart';
void main() {}
''');

      final app = makeProject('app', deps: ['core']);
      final core = makeProject('core');

      final implicit = await ImportAnalyzer.detectImplicitDependencies(
        project: app,
        allProjects: [app, core],
      );

      expect(implicit, isEmpty);
    });

    test('does not flag imports of non-workspace packages', () async {
      final appLib = Directory(p.join(tempDir.path, 'app', 'lib'));
      await appLib.create(recursive: true);
      await File(p.join(appLib.path, 'main.dart')).writeAsString('''
import 'package:http/http.dart';
void main() {}
''');

      final app = makeProject('app');

      final implicit = await ImportAnalyzer.detectImplicitDependencies(
        project: app,
        allProjects: [app],
      );

      expect(implicit, isEmpty);
    });

    test('returns empty when no lib/ directory', () async {
      final app = makeProject('app');
      final utils = makeProject('utils');

      final implicit = await ImportAnalyzer.detectImplicitDependencies(
        project: app,
        allProjects: [app, utils],
      );

      expect(implicit, isEmpty);
    });
  });

  group('ImportAnalyzer.detectAllImplicit', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('all_implicit_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('detects implicit deps across multiple projects', () async {
      // app imports utils (undeclared), core imports nothing
      final appLib = Directory(p.join(tempDir.path, 'app', 'lib'));
      await appLib.create(recursive: true);
      await File(p.join(appLib.path, 'main.dart')).writeAsString('''
import 'package:utils/utils.dart';
import 'package:core/core.dart';
void main() {}
''');

      final coreLib = Directory(p.join(tempDir.path, 'core', 'lib'));
      await coreLib.create(recursive: true);
      await File(
        p.join(coreLib.path, 'core.dart'),
      ).writeAsString('class Core {}');

      final utilsLib = Directory(p.join(tempDir.path, 'utils', 'lib'));
      await utilsLib.create(recursive: true);

      final app = Project(
        name: 'app',
        path: p.join(tempDir.path, 'app'),
        type: ProjectType.dartPackage,
        dependencies: ['core'], // only core is declared
        targets: {},
        tags: [],
      );
      final core = Project(
        name: 'core',
        path: p.join(tempDir.path, 'core'),
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
        tags: [],
      );
      final utils = Project(
        name: 'utils',
        path: p.join(tempDir.path, 'utils'),
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
        tags: [],
      );

      final result = await ImportAnalyzer.detectAllImplicit([app, core, utils]);

      expect(result, hasLength(1));
      expect(result['app'], ['utils']);
    });
  });
}
