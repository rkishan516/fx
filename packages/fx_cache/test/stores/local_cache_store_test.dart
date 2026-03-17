import 'dart:io';

import 'package:fx_cache/fx_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

CacheEntry makeEntry({
  String projectName = 'pkg',
  String targetName = 'test',
  int exitCode = 0,
  String inputHash = 'testhash',
}) => CacheEntry(
  projectName: projectName,
  targetName: targetName,
  exitCode: exitCode,
  stdout: 'output',
  stderr: '',
  duration: const Duration(seconds: 1),
  inputHash: inputHash,
);

void main() {
  group('LocalCacheStore', () {
    late Directory tempDir;
    late LocalCacheStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_local_cache_test_');
      store = LocalCacheStore(cacheDir: p.join(tempDir.path, '.fx_cache'));
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('has returns false for missing entry', () async {
      expect(await store.has('nonexistent'), isFalse);
    });

    test('get returns null for missing entry', () async {
      expect(await store.get('nonexistent'), isNull);
    });

    test('put and has returns true after storing', () async {
      final entry = makeEntry(inputHash: 'hash1');
      await store.put('hash1', entry);

      expect(await store.has('hash1'), isTrue);
    });

    test('put and get returns the stored entry', () async {
      final entry = makeEntry(
        projectName: 'my_pkg',
        targetName: 'analyze',
        exitCode: 0,
        inputHash: 'abc123',
      );
      await store.put('abc123', entry);

      final retrieved = await store.get('abc123');

      expect(retrieved, isNotNull);
      expect(retrieved!.projectName, equals('my_pkg'));
      expect(retrieved.targetName, equals('analyze'));
      expect(retrieved.exitCode, equals(0));
      expect(retrieved.inputHash, equals('abc123'));
    });

    test('put creates cache directory if it does not exist', () async {
      final cacheDir = Directory(p.join(tempDir.path, 'new_cache_dir'));
      expect(cacheDir.existsSync(), isFalse);

      final newStore = LocalCacheStore(cacheDir: cacheDir.path);
      await newStore.put('hash', makeEntry());

      expect(cacheDir.existsSync(), isTrue);
    });

    test('stores entries as JSON files named by hash', () async {
      await store.put('myhash', makeEntry());

      final cacheDir = Directory(p.join(tempDir.path, '.fx_cache'));
      final files = cacheDir.listSync().whereType<File>().toList();

      expect(files.length, equals(1));
      expect(p.basename(files.first.path), equals('myhash.json'));
    });

    test('can store and retrieve multiple entries', () async {
      await store.put('hash1', makeEntry(projectName: 'pkg1'));
      await store.put('hash2', makeEntry(projectName: 'pkg2'));
      await store.put('hash3', makeEntry(projectName: 'pkg3'));

      final e1 = await store.get('hash1');
      final e2 = await store.get('hash2');
      final e3 = await store.get('hash3');

      expect(e1!.projectName, equals('pkg1'));
      expect(e2!.projectName, equals('pkg2'));
      expect(e3!.projectName, equals('pkg3'));
    });

    test('clear removes all cached entries', () async {
      await store.put('hash1', makeEntry());
      await store.put('hash2', makeEntry());

      await store.clear();

      expect(await store.has('hash1'), isFalse);
      expect(await store.has('hash2'), isFalse);
    });

    test('clear on empty store does not throw', () async {
      await expectLater(store.clear(), completes);
    });

    test('get handles corrupted JSON gracefully by returning null', () async {
      // Create the cache dir and write a corrupted file
      final cacheDir = Directory(p.join(tempDir.path, '.fx_cache'));
      await cacheDir.create(recursive: true);
      await File(
        p.join(cacheDir.path, 'brokenhash.json'),
      ).writeAsString('not valid json {{{{');

      final result = await store.get('brokenhash');
      expect(result, isNull);
    });

    test('put overwrites existing entry with same hash', () async {
      final entry1 = makeEntry(projectName: 'old_name');
      await store.put('overwrite_hash', entry1);

      final entry2 = makeEntry(projectName: 'new_name');
      await store.put('overwrite_hash', entry2);

      final result = await store.get('overwrite_hash');
      expect(result!.projectName, equals('new_name'));
    });

    test('has returns false after clear', () async {
      await store.put('h1', makeEntry());
      expect(await store.has('h1'), isTrue);

      await store.clear();
      expect(await store.has('h1'), isFalse);
    });

    test('get handles empty JSON file by returning null', () async {
      final cacheDir = Directory(p.join(tempDir.path, '.fx_cache'));
      await cacheDir.create(recursive: true);
      await File(p.join(cacheDir.path, 'empty.json')).writeAsString('');

      final result = await store.get('empty');
      expect(result, isNull);
    });
  });
}
