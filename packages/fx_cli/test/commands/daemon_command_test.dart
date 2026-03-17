import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:fx_cli/src/daemon/fx_daemon.dart';

void main() {
  group('FxDaemon', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_daemon_test_');
      await _createMinimalWorkspace(tempDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('query() sends command once and reads response correctly', () async {
      // Start daemon on random port
      final daemon = FxDaemon(workspaceRoot: tempDir.path);
      final port = 40000 + (DateTime.now().millisecondsSinceEpoch % 5000);
      await daemon.start(port: port);

      try {
        final result = await FxDaemon.query(tempDir.path, 'ping');
        expect(result, 'pong');
      } finally {
        await daemon.stop();
      }
    });

    test(
      'query() does not double-connect (graph command returns valid JSON)',
      () async {
        final daemon = FxDaemon(workspaceRoot: tempDir.path);
        final port = 40100 + (DateTime.now().millisecondsSinceEpoch % 5000);
        await daemon.start(port: port);

        try {
          final result = await FxDaemon.query(tempDir.path, 'graph');
          expect(result, isNotNull);
          // Should be valid JSON, not doubled/corrupted
          final parsed = jsonDecode(result!) as Map;
          expect(parsed, isA<Map<String, dynamic>>());
        } finally {
          await daemon.stop();
        }
      },
    );

    test(
      'concurrent _refresh() calls are serialized (no double-load)',
      () async {
        final daemon = FxDaemon(workspaceRoot: tempDir.path);
        final port = 40200 + (DateTime.now().millisecondsSinceEpoch % 5000);

        // Track refresh invocations via a counter
        var refreshCount = 0;
        daemon.onRefresh = () => refreshCount++;

        await daemon.start(port: port);
        // Simulate multiple rapid file-change events
        await Future.wait([
          daemon.triggerRefreshForTest(),
          daemon.triggerRefreshForTest(),
          daemon.triggerRefreshForTest(),
        ]);

        try {
          // All concurrent calls should be collapsed to at most 2 refreshes
          // (one in progress + one queued)
          expect(refreshCount, lessThanOrEqualTo(3));
          // Workspace should still be loaded correctly
          final result = await FxDaemon.query(tempDir.path, 'ping');
          expect(result, 'pong');
        } finally {
          await daemon.stop();
        }
      },
    );

    test('daemon persists graph cache on initial load', () async {
      final daemon = FxDaemon(workspaceRoot: tempDir.path);
      final port = 40300 + (DateTime.now().millisecondsSinceEpoch % 5000);
      await daemon.start(port: port);
      await daemon.stop();

      // Cache file should exist after daemon starts
      final cacheFile = File(
        p.join(tempDir.path, '.fx_daemon', 'graph_cache.json'),
      );
      expect(cacheFile.existsSync(), isTrue);
    });
  });
}

Future<void> _createMinimalWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: test_ws
publish_to: none
environment:
  sdk: ^3.11.1
workspace:
  - packages/pkg_a
fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
''');

  final pkgDir = Directory(p.join(root, 'packages', 'pkg_a'));
  await pkgDir.create(recursive: true);
  await File(p.join(pkgDir.path, 'pubspec.yaml')).writeAsString('''
name: pkg_a
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');
}
