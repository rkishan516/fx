import 'dart:io';

import 'package:fx_cache/fx_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

CacheEntry makeEntry({
  String projectName = 'pkg',
  String targetName = 'test',
  int exitCode = 0,
  String inputHash = 'hash',
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
  group('CacheManager (local only)', () {
    late Directory tempDir;
    late CacheManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_cache_manager_test_');
      final localStore = LocalCacheStore(
        cacheDir: p.join(tempDir.path, '.fx_cache'),
      );
      manager = CacheManager(localStore: localStore);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('has returns false when nothing cached', () async {
      expect(await manager.has('missinghash'), isFalse);
    });

    test('get returns null when nothing cached', () async {
      expect(await manager.get('missinghash'), isNull);
    });

    test('put then has returns true', () async {
      await manager.put('h1', makeEntry());
      expect(await manager.has('h1'), isTrue);
    });

    test('put then get returns entry', () async {
      final entry = makeEntry(projectName: 'cached_pkg', inputHash: 'h2');
      await manager.put('h2', entry);

      final result = await manager.get('h2');
      expect(result, isNotNull);
      expect(result!.projectName, equals('cached_pkg'));
    });

    test('clearLocal removes all local entries', () async {
      await manager.put('h1', makeEntry());
      await manager.put('h2', makeEntry());

      await manager.clearLocal();

      expect(await manager.has('h1'), isFalse);
      expect(await manager.has('h2'), isFalse);
    });
  });

  group('CacheManager (with remote store)', () {
    late Directory tempDir;
    late CacheManager manager;
    late LocalCacheStore localStore;
    late FilesystemRemoteCacheStore remoteStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_cache_manager_test_');
      localStore = LocalCacheStore(
        cacheDir: p.join(tempDir.path, 'local_cache'),
      );
      remoteStore = FilesystemRemoteCacheStore(
        remotePath: p.join(tempDir.path, 'remote_cache'),
      );
      manager = CacheManager(localStore: localStore, remoteStore: remoteStore);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('put stores in both local and remote', () async {
      final entry = makeEntry(inputHash: 'synctest');
      await manager.put('synctest', entry);

      expect(await localStore.has('synctest'), isTrue);
      expect(await remoteStore.has('synctest'), isTrue);
    });

    test('get returns from local first without hitting remote', () async {
      final localEntry = makeEntry(projectName: 'from_local', inputHash: 'lh');
      await localStore.put('lh', localEntry);

      final result = await manager.get('lh');
      expect(result!.projectName, equals('from_local'));
    });

    test(
      'get fetches from remote when not in local and populates local',
      () async {
        final remoteEntry = makeEntry(
          projectName: 'from_remote',
          inputHash: 'rh',
        );
        await remoteStore.put('rh', remoteEntry);

        // local does not have it
        expect(await localStore.has('rh'), isFalse);

        final result = await manager.get('rh');
        expect(result, isNotNull);
        expect(result!.projectName, equals('from_remote'));

        // should now be cached locally
        expect(await localStore.has('rh'), isTrue);
      },
    );

    test('clearAll clears both local and remote', () async {
      await manager.put('ch1', makeEntry());
      await manager.put('ch2', makeEntry());

      await manager.clearAll();

      expect(await localStore.has('ch1'), isFalse);
      expect(await remoteStore.has('ch1'), isFalse);
      expect(await localStore.has('ch2'), isFalse);
      expect(await remoteStore.has('ch2'), isFalse);
    });
  });

  group('FilesystemRemoteCacheStore', () {
    late Directory tempDir;
    late FilesystemRemoteCacheStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_remote_cache_test_');
      store = FilesystemRemoteCacheStore(
        remotePath: p.join(tempDir.path, 'remote'),
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('has returns false for missing entry', () async {
      expect(await store.has('nope'), isFalse);
    });

    test('get returns null for missing entry', () async {
      expect(await store.get('nope'), isNull);
    });

    test('put and get round-trips', () async {
      final entry = makeEntry(projectName: 'remote_pkg', inputHash: 'rr');
      await store.put('rr', entry);

      final result = await store.get('rr');
      expect(result, isNotNull);
      expect(result!.projectName, equals('remote_pkg'));
    });

    test('clear removes all entries', () async {
      await store.put('r1', makeEntry());
      await store.put('r2', makeEntry());

      await store.clear();

      expect(await store.has('r1'), isFalse);
      expect(await store.has('r2'), isFalse);
    });

    test('creates directory on first put', () async {
      final remoteDir = Directory(p.join(tempDir.path, 'new_remote'));
      final newStore = FilesystemRemoteCacheStore(remotePath: remoteDir.path);
      expect(remoteDir.existsSync(), isFalse);

      await newStore.put('x', makeEntry());
      expect(remoteDir.existsSync(), isTrue);
    });
  });
}
