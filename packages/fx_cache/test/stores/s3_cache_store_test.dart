import 'dart:convert';
import 'dart:io';

import 'package:fx_cache/fx_cache.dart';
import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

CacheEntry _entry(String hash, {String stdout = ''}) => CacheEntry(
  projectName: 'proj',
  targetName: 'test',
  inputHash: hash,
  stdout: stdout,
  stderr: '',
  exitCode: 0,
  duration: Duration.zero,
);

void main() {
  group('S3RemoteCacheStore', () {
    late HttpServer server;
    late S3RemoteCacheStore store;
    final stored = <String, String>{};

    setUp(() async {
      stored.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final key = request.uri.path.replaceFirst('/', '');
        if (request.method == 'GET') {
          if (stored.containsKey(key)) {
            request.response
              ..statusCode = 200
              ..write(stored[key]);
          } else {
            request.response.statusCode = 404;
          }
        } else if (request.method == 'PUT') {
          final body = await utf8.decoder.bind(request).join();
          stored[key] = body;
          request.response.statusCode = 200;
        } else if (request.method == 'HEAD') {
          request.response.statusCode = stored.containsKey(key) ? 200 : 404;
        } else if (request.method == 'DELETE') {
          stored.clear();
          request.response.statusCode = 200;
        }
        await request.response.close();
      });

      store = S3RemoteCacheStore(
        bucket: 'test-bucket',
        endpoint: 'http://localhost:${server.port}',
        accessKey: 'test-key',
        secretKey: 'test-secret',
        region: 'us-east-1',
      );
    });

    tearDown(() async {
      await server.close();
    });

    test('put and get cache entry', () async {
      await store.put('abc123', _entry('abc123', stdout: 'hello output'));
      final retrieved = await store.get('abc123');

      expect(retrieved, isNotNull);
      expect(retrieved!.inputHash, 'abc123');
      expect(retrieved.stdout, 'hello output');
    });

    test('get returns null for missing entry', () async {
      expect(await store.get('nonexistent'), isNull);
    });

    test('has returns true for existing entry', () async {
      await store.put('exists', _entry('exists'));
      expect(await store.has('exists'), isTrue);
    });

    test('has returns false for missing entry', () async {
      expect(await store.has('missing'), isFalse);
    });

    test('clear removes all entries', () async {
      await store.put('x', _entry('x'));
      await store.clear();
      expect(await store.has('x'), isFalse);
    });
  });

  group('GcsRemoteCacheStore', () {
    late HttpServer server;
    late GcsRemoteCacheStore store;
    final stored = <String, String>{};

    setUp(() async {
      stored.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final key = request.uri.path.replaceFirst('/', '');
        if (request.method == 'GET') {
          if (stored.containsKey(key)) {
            request.response
              ..statusCode = 200
              ..write(stored[key]);
          } else {
            request.response.statusCode = 404;
          }
        } else if (request.method == 'PUT') {
          final body = await utf8.decoder.bind(request).join();
          stored[key] = body;
          request.response.statusCode = 200;
        } else if (request.method == 'HEAD') {
          request.response.statusCode = stored.containsKey(key) ? 200 : 404;
        } else if (request.method == 'DELETE') {
          stored.clear();
          request.response.statusCode = 200;
        }
        await request.response.close();
      });

      store = GcsRemoteCacheStore(
        bucket: 'test-bucket',
        endpoint: 'http://localhost:${server.port}',
        serviceAccountKey: '{}',
      );
    });

    tearDown(() async {
      await server.close();
    });

    test('put and get cache entry', () async {
      await store.put('gcs123', _entry('gcs123', stdout: 'gcs output'));
      final retrieved = await store.get('gcs123');

      expect(retrieved, isNotNull);
      expect(retrieved!.inputHash, 'gcs123');
      expect(retrieved.stdout, 'gcs output');
    });

    test('get returns null for missing entry', () async {
      expect(await store.get('missing'), isNull);
    });

    test('has works correctly', () async {
      expect(await store.has('missing'), isFalse);
      await store.put('h', _entry('h'));
      expect(await store.has('h'), isTrue);
    });
  });

  group('AzureRemoteCacheStore', () {
    late HttpServer server;
    late AzureRemoteCacheStore store;
    final stored = <String, String>{};

    setUp(() async {
      stored.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final key = request.uri.path.replaceFirst('/', '');
        if (request.method == 'GET') {
          if (stored.containsKey(key)) {
            request.response
              ..statusCode = 200
              ..write(stored[key]);
          } else {
            request.response.statusCode = 404;
          }
        } else if (request.method == 'PUT') {
          final body = await utf8.decoder.bind(request).join();
          stored[key] = body;
          request.response.statusCode = 201;
        } else if (request.method == 'HEAD') {
          request.response.statusCode = stored.containsKey(key) ? 200 : 404;
        } else if (request.method == 'DELETE') {
          stored.clear();
          request.response.statusCode = 200;
        }
        await request.response.close();
      });

      store = AzureRemoteCacheStore(
        accountName: 'testaccount',
        container: 'cache',
        endpoint: 'http://localhost:${server.port}',
        accountKey: 'test-key',
      );
    });

    tearDown(() async {
      await server.close();
    });

    test('put and get cache entry', () async {
      await store.put('az123', _entry('az123', stdout: 'azure output'));
      final retrieved = await store.get('az123');

      expect(retrieved, isNotNull);
      expect(retrieved!.inputHash, 'az123');
      expect(retrieved.stdout, 'azure output');
    });

    test('get returns null for missing entry', () async {
      expect(await store.get('missing'), isNull);
    });

    test('has works correctly', () async {
      expect(await store.has('missing'), isFalse);
      await store.put('h', _entry('h'));
      expect(await store.has('h'), isTrue);
    });

    test('clear removes all entries', () async {
      await store.put('x', _entry('x'));
      await store.clear();
      expect(await store.has('x'), isFalse);
    });

    test('constructor builds correct endpoint', () {
      final s = AzureRemoteCacheStore(
        accountName: 'myaccount',
        container: 'mycontainer',
        prefix: 'cache/',
      );
      expect(s.endpoint, 'https://myaccount.blob.core.windows.net/mycontainer');
    });
  });

  group('CacheConfig remote backends', () {
    test('S3 config from YAML', () {
      final store = S3RemoteCacheStore(
        bucket: 'my-cache',
        region: 'eu-west-1',
        prefix: 'fx/',
        accessKey: 'AK',
        secretKey: 'SK',
      );

      expect(store.bucket, 'my-cache');
      expect(store.region, 'eu-west-1');
      expect(store.prefix, 'fx/');
    });

    test('GCS config with defaults', () {
      final store = GcsRemoteCacheStore(bucket: 'my-bucket');

      expect(store.bucket, 'my-bucket');
      expect(store.prefix, '');
    });

    test('Azure config from constructor', () {
      final store = AzureRemoteCacheStore(
        accountName: 'myaccount',
        container: 'cache',
        prefix: 'fx/',
        accountKey: 'key123',
      );
      expect(store.accountName, 'myaccount');
      expect(store.container, 'cache');
      expect(store.prefix, 'fx/');
    });
  });

  group('CacheConfig remote backend parsing', () {
    test('parses string remote as http backend', () {
      final config = CacheConfig.fromYaml({
        'enabled': true,
        'remote': 'https://cache.example.com',
      });
      expect(config.remoteUrl, 'https://cache.example.com');
      expect(config.remoteBackend, 'http');
    });

    test('parses structured remote with s3 backend', () {
      final config = CacheConfig.fromYaml({
        'enabled': true,
        'remote': {
          'backend': 's3',
          'bucket': 'my-cache',
          'region': 'us-east-1',
        },
      });
      expect(config.remoteBackend, 's3');
      expect(config.remoteOptions['bucket'], 'my-cache');
      expect(config.remoteOptions['region'], 'us-east-1');
    });

    test('parses structured remote with azure backend', () {
      final config = CacheConfig.fromYaml({
        'enabled': true,
        'remote': {
          'backend': 'azure',
          'accountName': 'myaccount',
          'container': 'cache',
        },
      });
      expect(config.remoteBackend, 'azure');
      expect(config.remoteOptions['accountName'], 'myaccount');
      expect(config.remoteOptions['container'], 'cache');
    });

    test('falls back to legacy remoteUrl', () {
      final config = CacheConfig.fromYaml({
        'enabled': true,
        'remoteUrl': 'https://legacy.example.com',
      });
      expect(config.remoteUrl, 'https://legacy.example.com');
      expect(config.remoteBackend, 'http');
    });

    test('defaults remote to null when not specified', () {
      final config = CacheConfig.fromYaml({'enabled': true});
      expect(config.remoteUrl, isNull);
      expect(config.remoteBackend, isNull);
      expect(config.remoteOptions, isEmpty);
    });
  });
}
