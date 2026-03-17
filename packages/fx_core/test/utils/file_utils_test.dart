import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fx_file_utils_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('FileUtils.findWorkspaceRoot', () {
    test('finds root with fx.yaml', () {
      File(
        p.join(tempDir.path, 'fx.yaml'),
      ).writeAsStringSync('packages:\n  - packages/*\n');

      final result = FileUtils.findWorkspaceRoot(tempDir.path);
      expect(result, equals(tempDir.path));
    });

    test('finds root with pubspec.yaml containing fx: section', () {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: ws
environment:
  sdk: ^3.11.1
fx:
  packages:
    - packages/*
''');

      final result = FileUtils.findWorkspaceRoot(tempDir.path);
      expect(result, equals(tempDir.path));
    });

    test('walks up from subdirectory to find root', () {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: ws
fx:
  packages:
    - packages/*
''');
      final subDir = Directory(p.join(tempDir.path, 'packages', 'pkg_a', 'lib'))
        ..createSync(recursive: true);

      final result = FileUtils.findWorkspaceRoot(subDir.path);
      expect(result, equals(tempDir.path));
    });

    test('returns null when no workspace found', () {
      final isolated = Directory(p.join(tempDir.path, 'no_ws'))..createSync();

      final result = FileUtils.findWorkspaceRoot(isolated.path);
      expect(result, isNull);
    });

    test('ignores pubspec.yaml without fx: section', () {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: plain_package
version: 1.0.0
''');

      final result = FileUtils.findWorkspaceRoot(tempDir.path);
      expect(result, isNull);
    });

    test('prefers fx.yaml over pubspec.yaml', () {
      File(
        p.join(tempDir.path, 'fx.yaml'),
      ).writeAsStringSync('packages:\n  - from_fx/*\n');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: ws
fx:
  packages:
    - from_pubspec/*
''');

      // Should find root via fx.yaml first
      final result = FileUtils.findWorkspaceRoot(tempDir.path);
      expect(result, equals(tempDir.path));
    });
  });

  group('FileUtils.ensureDir', () {
    test('creates directory if it does not exist', () {
      final dirPath = p.join(tempDir.path, 'new_dir', 'sub_dir');
      expect(Directory(dirPath).existsSync(), isFalse);

      final result = FileUtils.ensureDir(dirPath);
      expect(result.existsSync(), isTrue);
      expect(result.path, equals(dirPath));
    });

    test('returns existing directory without error', () {
      final dirPath = p.join(tempDir.path, 'existing');
      Directory(dirPath).createSync();

      final result = FileUtils.ensureDir(dirPath);
      expect(result.existsSync(), isTrue);
    });
  });

  group('FileUtils.readFileOrNull', () {
    test('returns content for existing file', () {
      final filePath = p.join(tempDir.path, 'test.txt');
      File(filePath).writeAsStringSync('hello world');

      expect(FileUtils.readFileOrNull(filePath), equals('hello world'));
    });

    test('returns null for non-existent file', () {
      final filePath = p.join(tempDir.path, 'missing.txt');
      expect(FileUtils.readFileOrNull(filePath), isNull);
    });
  });

  group('FileUtils.writeFile', () {
    test('creates file and parent directories', () {
      final filePath = p.join(tempDir.path, 'deep', 'nested', 'file.txt');
      FileUtils.writeFile(filePath, 'content');

      expect(File(filePath).existsSync(), isTrue);
      expect(File(filePath).readAsStringSync(), equals('content'));
    });

    test('overwrites existing file', () {
      final filePath = p.join(tempDir.path, 'overwrite.txt');
      File(filePath).writeAsStringSync('old');

      FileUtils.writeFile(filePath, 'new');
      expect(File(filePath).readAsStringSync(), equals('new'));
    });
  });

  group('FileUtils.deleteFile', () {
    test('deletes existing file', () {
      final filePath = p.join(tempDir.path, 'to_delete.txt');
      File(filePath).writeAsStringSync('bye');

      FileUtils.deleteFile(filePath);
      expect(File(filePath).existsSync(), isFalse);
    });

    test('does nothing for non-existent file', () {
      final filePath = p.join(tempDir.path, 'not_here.txt');
      // Should not throw
      FileUtils.deleteFile(filePath);
      expect(File(filePath).existsSync(), isFalse);
    });
  });

  group('FileUtils.findPubspecs', () {
    test('finds pubspecs matching wildcard pattern', () {
      for (final name in ['pkg_a', 'pkg_b']) {
        final dir = Directory(p.join(tempDir.path, 'packages', name))
          ..createSync(recursive: true);
        File(
          p.join(dir.path, 'pubspec.yaml'),
        ).writeAsStringSync('name: $name\n');
      }

      final results = FileUtils.findPubspecs(tempDir.path, ['packages/*']);
      expect(results, hasLength(2));
      expect(results.any((r) => r.contains('pkg_a')), isTrue);
      expect(results.any((r) => r.contains('pkg_b')), isTrue);
    });

    test('finds pubspec at direct path (no wildcard)', () {
      final dir = Directory(p.join(tempDir.path, 'single_pkg'))..createSync();
      File(
        p.join(dir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: single\n');

      final results = FileUtils.findPubspecs(tempDir.path, ['single_pkg']);
      expect(results, hasLength(1));
    });

    test('returns empty for non-existent directory', () {
      final results = FileUtils.findPubspecs(tempDir.path, ['nonexistent/*']);
      expect(results, isEmpty);
    });

    test('returns empty when directory has no pubspec', () {
      Directory(
        p.join(tempDir.path, 'packages', 'empty_pkg'),
      ).createSync(recursive: true);

      final results = FileUtils.findPubspecs(tempDir.path, ['packages/*']);
      expect(results, isEmpty);
    });

    test('supports multiple patterns', () {
      for (final dir in ['packages/lib_a', 'apps/app_a']) {
        final d = Directory(p.join(tempDir.path, dir))
          ..createSync(recursive: true);
        File(
          p.join(d.path, 'pubspec.yaml'),
        ).writeAsStringSync('name: ${p.basename(dir)}\n');
      }

      final results = FileUtils.findPubspecs(tempDir.path, [
        'packages/*',
        'apps/*',
      ]);
      expect(results, hasLength(2));
    });

    test('ignores non-directory entities under wildcard', () {
      Directory(p.join(tempDir.path, 'packages')).createSync();
      // Create a file (not a directory) under packages/
      File(
        p.join(tempDir.path, 'packages', 'README.md'),
      ).writeAsStringSync('readme');

      final results = FileUtils.findPubspecs(tempDir.path, ['packages/*']);
      expect(results, isEmpty);
    });
  });
}
