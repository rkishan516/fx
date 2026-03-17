import 'dart:io';

import 'package:fx_cache/fx_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('OutputCollector', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_output_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('collects files matching output patterns', () async {
      // Create build output files
      final buildDir = p.join(tempDir.path, 'build');
      Directory(buildDir).createSync();
      File(p.join(buildDir, 'app.js')).writeAsStringSync('console.log("hi");');
      File(p.join(buildDir, 'app.css')).writeAsStringSync('body{}');

      final artifacts = await OutputCollector.collect(
        projectPath: tempDir.path,
        outputPatterns: ['build/**'],
      );

      expect(artifacts, hasLength(2));
      expect(artifacts['build/app.js'], equals('console.log("hi");'));
      expect(artifacts['build/app.css'], equals('body{}'));
    });

    test('collects direct file path', () async {
      File(p.join(tempDir.path, 'output.txt')).writeAsStringSync('result');

      final artifacts = await OutputCollector.collect(
        projectPath: tempDir.path,
        outputPatterns: ['output.txt'],
      );

      expect(artifacts, hasLength(1));
      expect(artifacts['output.txt'], equals('result'));
    });

    test('returns empty for nonexistent pattern', () async {
      final artifacts = await OutputCollector.collect(
        projectPath: tempDir.path,
        outputPatterns: ['nonexistent/**'],
      );

      expect(artifacts, isEmpty);
    });

    test('restores artifacts to project path', () async {
      final artifacts = {
        'build/app.js': 'restored_js',
        'build/styles/main.css': 'restored_css',
      };

      final count = await OutputCollector.restore(
        projectPath: tempDir.path,
        artifacts: artifacts,
      );

      expect(count, equals(2));
      expect(
        File(p.join(tempDir.path, 'build', 'app.js')).readAsStringSync(),
        equals('restored_js'),
      );
      expect(
        File(
          p.join(tempDir.path, 'build', 'styles', 'main.css'),
        ).readAsStringSync(),
        equals('restored_css'),
      );
    });

    test('round-trip: collect then restore', () async {
      // Create original build outputs
      final buildDir = p.join(tempDir.path, 'project_a', 'build');
      Directory(buildDir).createSync(recursive: true);
      File(p.join(buildDir, 'output.dart')).writeAsStringSync('void main(){}');

      // Collect
      final artifacts = await OutputCollector.collect(
        projectPath: p.join(tempDir.path, 'project_a'),
        outputPatterns: ['build/**'],
      );

      // Restore to a different location
      final restoreDir = p.join(tempDir.path, 'project_b');
      Directory(restoreDir).createSync();

      await OutputCollector.restore(
        projectPath: restoreDir,
        artifacts: artifacts,
      );

      expect(
        File(p.join(restoreDir, 'build', 'output.dart')).readAsStringSync(),
        equals('void main(){}'),
      );
    });
  });
}
