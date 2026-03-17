import 'dart:io';

import 'package:fx_cli/fx_cli.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CacheCommand', () {
    late Directory workspaceDir;

    setUp(() async {
      workspaceDir = await Directory.systemTemp.createTemp(
        'fx_cache_cmd_test_',
      );
      await _createMinimalWorkspace(workspaceDir.path);
    });

    tearDown(() async {
      await workspaceDir.delete(recursive: true);
    });

    test('cache clear removes all cached entries', () async {
      // Pre-populate the cache directory
      final cacheDir = Directory(p.join(workspaceDir.path, '.fx_cache'));
      await cacheDir.create(recursive: true);
      await File(
        p.join(cacheDir.path, 'abc123.json'),
      ).writeAsString('{"fake": "entry"}');
      await File(
        p.join(cacheDir.path, 'def456.json'),
      ).writeAsString('{"fake": "entry"}');

      expect(cacheDir.listSync().whereType<File>().length, equals(2));

      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );

      await runner.run(['cache', 'clear', '--workspace', workspaceDir.path]);

      expect(cacheDir.listSync().whereType<File>().length, equals(0));
    });

    test('cache status shows entry count and size', () async {
      final cacheDir = Directory(p.join(workspaceDir.path, '.fx_cache'));
      await cacheDir.create(recursive: true);
      await File(
        p.join(cacheDir.path, 'hash1.json'),
      ).writeAsString('{"data": "hello world"}');
      await File(
        p.join(cacheDir.path, 'hash2.json'),
      ).writeAsString('{"data": "foo bar"}');

      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );

      await runner.run(['cache', 'status', '--workspace', workspaceDir.path]);

      final output = buffer.toString();
      expect(output, contains('2')); // 2 entries
    });

    test('cache clear on empty cache does not throw', () async {
      final cacheDir = p.join(workspaceDir.path, '.fx_cache');

      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final runner = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir,
      );

      await expectLater(
        runner.run(['cache', 'clear', '--workspace', workspaceDir.path]),
        completes,
      );
    });

    test('cache status on empty cache shows zero entries', () async {
      final cacheDir = p.join(workspaceDir.path, '.fx_cache');

      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final buffer = StringBuffer();
      final runner = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
        cacheDir: cacheDir,
      );

      await runner.run(['cache', 'status', '--workspace', workspaceDir.path]);

      expect(buffer.toString(), contains('0'));
    });

    test('cache clear then status shows zero', () async {
      final cacheDir = Directory(p.join(workspaceDir.path, '.fx_cache'));
      await cacheDir.create(recursive: true);
      await File(
        p.join(cacheDir.path, 'entry.json'),
      ).writeAsString('{"data": "test"}');

      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );

      // Clear
      final runner1 = FxCommandRunner(
        outputSink: StringBuffer(),
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runner1.run(['cache', 'clear', '--workspace', workspaceDir.path]);

      // Status
      final buffer = StringBuffer();
      final runner2 = FxCommandRunner(
        outputSink: buffer,
        processRunner: mockRunner,
        cacheDir: cacheDir.path,
      );
      await runner2.run(['cache', 'status', '--workspace', workspaceDir.path]);

      expect(buffer.toString(), contains('0'));
    });
  });
}

Future<void> _createMinimalWorkspace(String root) async {
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: test_workspace
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
  cache:
    enabled: true
    directory: .fx_cache
''');

  final pkgADir = Directory(p.join(root, 'packages', 'pkg_a'));
  await pkgADir.create(recursive: true);
  await File(p.join(pkgADir.path, 'pubspec.yaml')).writeAsString('''
name: pkg_a
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ^3.11.1
''');
}
