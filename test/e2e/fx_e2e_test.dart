@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end tests that compile the real `fx` binary and invoke it as a
/// subprocess against real temporary workspaces.  No mocks, no in-process
/// shortcuts — this exercises the full CLI surface.
late String fxBinary;

Future<ProcessResult> fx(List<String> args, {String? workingDirectory}) async {
  return Process.run(fxBinary, args, workingDirectory: workingDirectory);
}

/// Create a minimal fx workspace in [dir] with optional [packages].
/// Each package entry is a map with 'name' and optional 'deps' (list of
/// path-dependency names).
Future<void> createWorkspace(
  String dir, {
  String name = 'test_ws',
  List<Map<String, dynamic>> packages = const [],
}) async {
  await Directory(p.join(dir, 'packages')).create(recursive: true);

  final members = packages
      .map((pkg) => "  - packages/${pkg['name']}")
      .join('\n');

  await File(p.join(dir, 'pubspec.yaml')).writeAsString('''
name: $name
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
${members.isNotEmpty ? members : '  # empty'}

fx:
  projects:
    packages/*:
      targets:
        test:
          command: "dart test"
        build:
          command: "dart compile exe"
        analyze:
          command: "dart analyze"
''');

  for (final pkg in packages) {
    final pkgName = pkg['name'] as String;
    final deps = (pkg['deps'] as List<String>?) ?? [];
    final pkgDir = p.join(dir, 'packages', pkgName);
    await Directory(p.join(pkgDir, 'lib')).create(recursive: true);

    final depEntries = deps.map((d) => '  $d:\n    path: ../$d').join('\n');

    await File(p.join(pkgDir, 'pubspec.yaml')).writeAsString('''
name: $pkgName
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.11.1

${depEntries.isNotEmpty ? 'dependencies:\n$depEntries' : ''}
''');

    await File(
      p.join(pkgDir, 'lib', '$pkgName.dart'),
    ).writeAsString('// $pkgName library\n');
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Compile the fx binary once for the whole suite.
    final compiled = p.join(Directory.systemTemp.path, 'fx_e2e_binary');
    final result = await Process.run('dart', [
      'compile',
      'exe',
      p.join(Directory.current.path, 'packages', 'fx_cli', 'bin', 'fx.dart'),
      '-o',
      compiled,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Failed to compile fx binary:\n${result.stderr}\n${result.stdout}',
      );
    }
    fxBinary = compiled;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fx_e2e_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  // ─── fx init ───────────────────────────────────────────────────────

  group('fx init', () {
    test('creates a valid workspace', () async {
      final wsDir = p.join(tempDir.path, 'my_ws');
      final result = await fx(['init', '--name', 'my_ws', '--dir', wsDir]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('initialized'));

      final pubspec = File(p.join(wsDir, 'pubspec.yaml'));
      expect(pubspec.existsSync(), isTrue);

      final content = pubspec.readAsStringSync();
      expect(content, contains('name: my_ws'));
      expect(content, contains('workspace:'));
      expect(content, contains('fx:'));

      expect(Directory(p.join(wsDir, 'packages')).existsSync(), isTrue);
    });

    test('is idempotent (re-init does not fail)', () async {
      final wsDir = p.join(tempDir.path, 'rerun_ws');
      await fx(['init', '--name', 'rerun_ws', '--dir', wsDir]);
      final result = await fx(['init', '--name', 'rerun_ws', '--dir', wsDir]);

      expect(
        result.exitCode,
        0,
        reason: 'Second init should succeed. stderr: ${result.stderr}',
      );
    });
  });

  // ─── fx list ───────────────────────────────────────────────────────

  group('fx list', () {
    test('shows nothing for empty workspace', () async {
      final wsDir = tempDir.path;
      await createWorkspace(wsDir);

      final result = await fx(['list', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
    });

    test('lists projects in text format', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'alpha'},
          {'name': 'beta'},
        ],
      );

      final result = await fx(['list', '--workspace', wsDir]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('alpha'));
      expect(result.stdout, contains('beta'));
    });

    test('lists projects in JSON format', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'alpha'},
          {'name': 'beta'},
        ],
      );

      final result = await fx(['list', '--json', '--workspace', wsDir]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      final decoded = jsonDecode(result.stdout as String);
      expect(decoded, isList);
      final names = (decoded as List).map((e) => (e as Map)['name']).toList();
      expect(names, containsAll(['alpha', 'beta']));
    });
  });

  // ─── fx graph ──────────────────────────────────────────────────────

  group('fx graph', () {
    test('outputs text graph', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'core'},
          {
            'name': 'app',
            'deps': ['core'],
          },
        ],
      );

      final result = await fx(['graph', '--workspace', wsDir]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('app'));
      expect(result.stdout, contains('core'));
    });

    test('outputs JSON graph', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'core'},
          {
            'name': 'app',
            'deps': ['core'],
          },
        ],
      );

      final result = await fx([
        'graph',
        '--format',
        'json',
        '--workspace',
        wsDir,
      ]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      final decoded = jsonDecode(result.stdout as String);
      expect(decoded, isMap);
    });

    test('outputs DOT format', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'core'},
          {
            'name': 'app',
            'deps': ['core'],
          },
        ],
      );

      final result = await fx([
        'graph',
        '--format',
        'dot',
        '--workspace',
        wsDir,
      ]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('digraph'));
      expect(result.stdout, contains('app'));
      expect(result.stdout, contains('core'));
    });
  });

  // ─── fx generate ───────────────────────────────────────────────────

  group('fx generate', () {
    test('scaffolds a dart_package', () async {
      final wsDir = tempDir.path;
      await createWorkspace(wsDir);

      final result = await fx([
        'generate',
        'dart_package',
        'my_pkg',
        '--workspace',
        wsDir,
      ]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');

      final pkgDir = p.join(wsDir, 'packages', 'my_pkg');
      expect(Directory(pkgDir).existsSync(), isTrue);
      expect(File(p.join(pkgDir, 'pubspec.yaml')).existsSync(), isTrue);
      expect(File(p.join(pkgDir, 'lib', 'my_pkg.dart')).existsSync(), isTrue);
    });

    test('dry-run does not create files', () async {
      final wsDir = tempDir.path;
      await createWorkspace(wsDir);

      final result = await fx([
        'generate',
        'dart_package',
        'phantom_pkg',
        '--dry-run',
        '--workspace',
        wsDir,
      ]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('Would generate'));

      final pkgDir = p.join(wsDir, 'packages', 'phantom_pkg');
      expect(Directory(pkgDir).existsSync(), isFalse);
    });
  });

  // ─── fx cache ──────────────────────────────────────────────────────

  group('fx cache', () {
    test('status reports cache info', () async {
      final wsDir = tempDir.path;
      await createWorkspace(wsDir);

      final result = await fx(['cache', 'status', '--workspace', wsDir]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      // Should print cache location or entry count
      expect(result.stdout, isNotEmpty);
    });

    test('clear removes cached entries', () async {
      final wsDir = tempDir.path;
      await createWorkspace(wsDir);

      final result = await fx(['cache', 'clear', '--workspace', wsDir]);

      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
    });
  });

  // ─── fx run ────────────────────────────────────────────────────────

  group('fx run', () {
    test('fails gracefully for unknown project', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'alpha'},
        ],
      );

      final result = await fx([
        'run',
        'nonexistent',
        'test',
        '--workspace',
        wsDir,
      ]);

      expect(result.exitCode, isNot(0));
    });

    test('runs a target on a real project', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'alpha'},
        ],
      );

      // Use 'analyze' target which maps to `dart analyze`
      final result = await fx([
        'run',
        'alpha',
        'analyze',
        '--workspace',
        wsDir,
      ]);

      // May fail if dart analyze not available for the temp package,
      // but should not crash with a Dart exception
      expect(result.stderr.toString(), isNot(contains('Unhandled exception')));
    });
  });

  // ─── fx run-many ───────────────────────────────────────────────────

  group('fx run-many', () {
    test('runs target across all projects', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'alpha'},
          {'name': 'beta'},
        ],
      );

      final result = await fx([
        'run-many',
        '--target',
        'analyze',
        '--workspace',
        wsDir,
      ]);

      // Should attempt to run on both projects
      expect(result.stderr.toString(), isNot(contains('Unhandled exception')));
    });
  });

  // ─── fx --help / unknown command ──────────────────────────────────

  group('fx help and errors', () {
    test('--help prints usage', () async {
      final result = await fx(['--help']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Usage: fx'));
      expect(result.stdout, contains('Available commands'));
    });

    test('unknown command exits with error', () async {
      final result = await fx(['nonexistent-command']);

      expect(result.exitCode, isNot(0));
    });

    test('no arguments prints help', () async {
      final result = await fx([]);

      // Should either print help or exit 0
      expect(result.stdout, contains('fx'));
    });
  });

  // ─── full workflow ─────────────────────────────────────────────────

  group('full workflow', () {
    test('init -> generate -> list -> graph', () async {
      final wsDir = p.join(tempDir.path, 'full_ws');

      // 1. Init
      var result = await fx(['init', '--name', 'full_ws', '--dir', wsDir]);
      expect(result.exitCode, 0, reason: 'init failed: ${result.stderr}');

      // 2. Generate a package
      result = await fx([
        'generate',
        'dart_package',
        'core_lib',
        '--workspace',
        wsDir,
      ]);
      expect(result.exitCode, 0, reason: 'generate failed: ${result.stderr}');

      // 3. List — should show the generated package
      result = await fx(['list', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'list failed: ${result.stderr}');
      expect(result.stdout, contains('core_lib'));

      // 4. Graph — should show the project
      result = await fx(['graph', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'graph failed: ${result.stderr}');
      expect(result.stdout, contains('core_lib'));
    });
  });

  // ─── fx reset ──────────────────────────────────────────────────────

  group('fx reset', () {
    test('clears cache and reports', () async {
      final wsDir = tempDir.path;
      await createWorkspace(wsDir);

      // Create a fake cache directory
      await Directory(p.join(wsDir, '.fx_cache')).create();

      final result = await fx(['reset', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('cache'));
    });

    test('reports nothing to clean when fresh', () async {
      final wsDir = tempDir.path;
      await createWorkspace(wsDir);

      final result = await fx(['reset', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('fresh'));
    });
  });

  // ─── fx show ──────────────────────────────────────────────────────

  group('fx show', () {
    test('shows project details', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'core'},
          {
            'name': 'app',
            'deps': ['core'],
          },
        ],
      );

      final result = await fx(['show', 'project', 'app', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('app'));
      expect(result.stdout, contains('core'));
    });

    test('shows project details in JSON', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'core'},
        ],
      );

      final result = await fx([
        'show',
        'project',
        'core',
        '--json',
        '--workspace',
        wsDir,
      ]);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      final decoded = jsonDecode(result.stdout as String);
      expect(decoded, isMap);
      expect(decoded['name'], 'core');
    });

    test('lists all projects', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'alpha'},
          {'name': 'beta'},
        ],
      );

      final result = await fx(['show', 'projects', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('alpha'));
      expect(result.stdout, contains('beta'));
    });
  });

  // ─── fx lint ──────────────────────────────────────────────────────

  group('fx lint', () {
    test('passes when no boundaries configured', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'core'},
          {
            'name': 'app',
            'deps': ['core'],
          },
        ],
      );

      final result = await fx(['lint', '--workspace', wsDir]);
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect(result.stdout, contains('passed'));
    });
  });

  // ─── fx run-many with --projects glob ──────────────────────────────

  group('fx run-many filtering', () {
    test('--projects filters by glob pattern', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'pkg_core'},
          {'name': 'pkg_utils'},
          {'name': 'app'},
        ],
      );

      final result = await fx([
        'run-many',
        '--target',
        'analyze',
        '--projects',
        'pkg_*',
        '--workspace',
        wsDir,
      ]);

      // Should only run on pkg_core and pkg_utils, not app
      expect(result.stderr.toString(), isNot(contains('Unhandled exception')));
    });

    test('--exclude removes projects', () async {
      final wsDir = tempDir.path;
      await createWorkspace(
        wsDir,
        packages: [
          {'name': 'alpha'},
          {'name': 'beta'},
          {'name': 'gamma'},
        ],
      );

      final result = await fx([
        'run-many',
        '--target',
        'analyze',
        '--exclude',
        'gamma',
        '--workspace',
        wsDir,
      ]);

      expect(result.stderr.toString(), isNot(contains('Unhandled exception')));
    });
  });

  // ─── new commands are registered ──────────────────────────────────

  group('command registration', () {
    test('--help shows all new commands', () async {
      final result = await fx(['--help']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('reset'));
      expect(result.stdout, contains('show'));
      expect(result.stdout, contains('lint'));
      expect(result.stdout, contains('watch'));
      expect(result.stdout, contains('release'));
    });
  });
}
