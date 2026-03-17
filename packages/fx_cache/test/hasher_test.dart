import 'dart:io';

import 'package:fx_cache/fx_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Hasher', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_hasher_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('hashString produces consistent SHA-256 hex digest', () {
      final hash1 = Hasher.hashString('hello world');
      final hash2 = Hasher.hashString('hello world');

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 = 32 bytes = 64 hex chars
      expect(hash1, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('hashString produces different digests for different inputs', () {
      final hash1 = Hasher.hashString('input A');
      final hash2 = Hasher.hashString('input B');

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashInputs produces consistent hash for same files', () async {
      // Create test project structure
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      await File(
        p.join(libDir.path, 'main.dart'),
      ).writeAsString('void main() {}');
      await File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).writeAsString('name: test_pkg\nversion: 1.0.0\n');

      final hash1 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**', 'pubspec.yaml'],
      );

      final hash2 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**', 'pubspec.yaml'],
      );

      expect(hash1, equals(hash2));
    });

    test('hashInputs changes when file content changes', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      final mainFile = File(p.join(libDir.path, 'main.dart'));
      await mainFile.writeAsString('void main() {}');

      final hash1 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      // Modify the file
      await mainFile.writeAsString('void main() { print("changed"); }');

      final hash2 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashInputs changes when executor changes', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      await File(
        p.join(libDir.path, 'main.dart'),
      ).writeAsString('void main() {}');

      final hash1 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      final hash2 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'flutter test',
        inputPatterns: ['lib/**'],
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashInputs changes when targetName changes', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      await File(
        p.join(libDir.path, 'main.dart'),
      ).writeAsString('void main() {}');

      final hash1 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      final hash2 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'analyze',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashInputs handles empty file set gracefully', () async {
      final hash = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hash, isNotEmpty);
      expect(hash.length, equals(64));
    });

    test('hashInputs returns 64-char hex string', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      await File(p.join(libDir.path, 'src.dart')).writeAsString('// code');

      final hash = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hash.length, equals(64));
      expect(hash, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('hashInputs changes when a new file is added', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      await File(p.join(libDir.path, 'a.dart')).writeAsString('// a');

      final hash1 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      // Add a new file
      await File(p.join(libDir.path, 'b.dart')).writeAsString('// b');

      final hash2 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashInputs changes when a file is removed', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      await File(p.join(libDir.path, 'a.dart')).writeAsString('// a');
      final bFile = File(p.join(libDir.path, 'b.dart'));
      await bFile.writeAsString('// b');

      final hash1 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      // Remove a file
      await bFile.delete();

      final hash2 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashInputs is file-order independent (sorted)', () async {
      // Create two different temp dirs with same files in different order
      final dir1 = await Directory.systemTemp.createTemp('fx_hash_order1_');
      final dir2 = await Directory.systemTemp.createTemp('fx_hash_order2_');
      try {
        final lib1 = await Directory(p.join(dir1.path, 'lib')).create();
        final lib2 = await Directory(p.join(dir2.path, 'lib')).create();

        // Write files in different order to different dirs
        await File(p.join(lib1.path, 'a.dart')).writeAsString('// a');
        await File(p.join(lib1.path, 'z.dart')).writeAsString('// z');

        await File(p.join(lib2.path, 'z.dart')).writeAsString('// z');
        await File(p.join(lib2.path, 'a.dart')).writeAsString('// a');

        final hash1 = await Hasher.hashInputs(
          projectPath: dir1.path,
          targetName: 'test',
          executor: 'dart test',
          inputPatterns: ['lib/**'],
        );
        final hash2 = await Hasher.hashInputs(
          projectPath: dir2.path,
          targetName: 'test',
          executor: 'dart test',
          inputPatterns: ['lib/**'],
        );

        expect(hash1, equals(hash2));
      } finally {
        await dir1.delete(recursive: true);
        await dir2.delete(recursive: true);
      }
    });

    test('hashInputs with multiple input patterns', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      final testDir = await Directory(p.join(tempDir.path, 'test')).create();
      await File(p.join(libDir.path, 'code.dart')).writeAsString('// lib');
      await File(p.join(testDir.path, 'test.dart')).writeAsString('// test');

      final hashBoth = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**', 'test/**'],
      );

      final hashLibOnly = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hashBoth, isNot(equals(hashLibOnly)));
    });

    test(
      'hashInputs with nonexistent pattern returns consistent hash',
      () async {
        final hash = await Hasher.hashInputs(
          projectPath: tempDir.path,
          targetName: 'test',
          executor: 'dart test',
          inputPatterns: ['nonexistent/**'],
        );
        expect(hash, isNotEmpty);
        expect(hash.length, equals(64));
      },
    );

    test('hashInputs includes env variable values', () async {
      final hash1 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ["env('PATH')"],
      );

      // env('PATH') should produce a valid hash
      expect(hash1, isNotEmpty);
      expect(hash1.length, equals(64));

      // Hash with a different env var should differ
      final hash2 = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ["env('HOME')"],
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashInputs mixes env and file patterns', () async {
      final libDir = await Directory(p.join(tempDir.path, 'lib')).create();
      await File(p.join(libDir.path, 'a.dart')).writeAsString('// a');

      final hashWithEnv = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**', "env('HOME')"],
      );

      final hashWithoutEnv = await Hasher.hashInputs(
        projectPath: tempDir.path,
        targetName: 'test',
        executor: 'dart test',
        inputPatterns: ['lib/**'],
      );

      expect(hashWithEnv, isNot(equals(hashWithoutEnv)));
    });
  });
}
