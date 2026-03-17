import 'dart:convert';
import 'dart:io';

import 'package:fx_cache/fx_cache.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GraphCache', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fx_graph_cache_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    List<Project> makeProjects() => [
      Project(
        name: 'pkg_a',
        path: p.join(tempDir.path, 'packages', 'pkg_a'),
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      ),
      Project(
        name: 'pkg_b',
        path: p.join(tempDir.path, 'packages', 'pkg_b'),
        type: ProjectType.dartPackage,
        dependencies: ['pkg_a'],
        targets: {},
      ),
    ];

    test('save and load round-trips projects', () async {
      final projects = makeProjects();
      final graph = ProjectGraph.build(projects);
      final cache = GraphCache(
        cacheFile: File(p.join(tempDir.path, 'graph_cache.json')),
      );

      await cache.save(projects: projects, graph: graph, gitHash: 'abc123');
      final restored = await cache.load();

      expect(restored, isNotNull);
      expect(
        restored!.projects.map((p) => p.name).toList(),
        unorderedEquals(['pkg_a', 'pkg_b']),
      );
    });

    test('save stores git commit hash', () async {
      final projects = makeProjects();
      final graph = ProjectGraph.build(projects);
      final cacheFile = File(p.join(tempDir.path, 'graph_cache.json'));
      final cache = GraphCache(cacheFile: cacheFile);

      await cache.save(projects: projects, graph: graph, gitHash: 'def456');

      final raw = jsonDecode(cacheFile.readAsStringSync()) as Map;
      expect(raw['gitHash'], 'def456');
    });

    test('load returns null when cache file does not exist', () async {
      final cache = GraphCache(
        cacheFile: File(p.join(tempDir.path, 'no_cache.json')),
      );
      final result = await cache.load();
      expect(result, isNull);
    });

    test('cachedGitHash returns null for empty cache', () async {
      final cache = GraphCache(
        cacheFile: File(p.join(tempDir.path, 'no_cache.json')),
      );
      expect(await cache.cachedGitHash(), isNull);
    });

    test('cachedGitHash returns stored hash after save', () async {
      final projects = makeProjects();
      final graph = ProjectGraph.build(projects);
      final cache = GraphCache(
        cacheFile: File(p.join(tempDir.path, 'graph_cache.json')),
      );

      await cache.save(projects: projects, graph: graph, gitHash: 'ghi789');
      expect(await cache.cachedGitHash(), 'ghi789');
    });

    test('changedPackages returns all packages on empty cache', () async {
      final projects = makeProjects();
      final cache = GraphCache(
        cacheFile: File(p.join(tempDir.path, 'no_cache.json')),
      );

      final changed = await cache.changedPackages(
        projects: projects,
        workspaceRoot: tempDir.path,
      );
      expect(changed, unorderedEquals(['pkg_a', 'pkg_b']));
    });

    test('changedPackages returns packages containing changed files', () async {
      final projects = makeProjects();
      final graph = ProjectGraph.build(projects);

      // Create the pkg_b directory with a changed file
      final pkgBPath = p.join(tempDir.path, 'packages', 'pkg_b');
      Directory(pkgBPath).createSync(recursive: true);

      final cache = GraphCache(
        cacheFile: File(p.join(tempDir.path, 'graph_cache.json')),
        gitRunner: _FakeGitRunner(
          hash: 'abc',
          changedFiles: ['packages/pkg_b/lib/src/foo.dart'],
        ),
      );

      await cache.save(projects: projects, graph: graph, gitHash: 'prev_hash');
      final changed = await cache.changedPackages(
        projects: projects,
        workspaceRoot: tempDir.path,
      );
      expect(changed, contains('pkg_b'));
      expect(changed, isNot(contains('pkg_a')));
    });

    test(
      'changedPackages falls back to timestamps in non-git directories',
      () async {
        final projects = makeProjects();
        final graph = ProjectGraph.build(projects);

        // Create the pkg_a dir with a file modified after cache save time
        final pkgAPath = p.join(tempDir.path, 'packages', 'pkg_a');
        Directory(pkgAPath).createSync(recursive: true);
        final pkgBPath = p.join(tempDir.path, 'packages', 'pkg_b');
        Directory(pkgBPath).createSync(recursive: true);

        // Use a git runner that simulates "not a git repo"
        final cache = GraphCache(
          cacheFile: File(p.join(tempDir.path, 'graph_cache.json')),
          gitRunner: _FakeGitRunner(notGitRepo: true),
        );

        // Save first
        await cache.save(projects: projects, graph: graph, gitHash: null);

        // Simulate a file change by writing after save
        await Future.delayed(const Duration(milliseconds: 10));
        File(p.join(pkgAPath, 'lib.dart')).writeAsStringSync('// changed');

        final changed = await cache.changedPackages(
          projects: projects,
          workspaceRoot: tempDir.path,
        );
        expect(changed, contains('pkg_a'));
      },
    );

    test('load restores graph with correct edges', () async {
      final projects = makeProjects();
      final graph = ProjectGraph.build(projects);
      final cache = GraphCache(
        cacheFile: File(p.join(tempDir.path, 'graph_cache.json')),
      );

      await cache.save(projects: projects, graph: graph, gitHash: 'xyz');
      final restored = await cache.load();

      expect(restored, isNotNull);
      final restoredGraph = restored!.graph;
      expect(restoredGraph.dependenciesOf('pkg_b'), contains('pkg_a'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Fake git runner for testing [GraphCache] without real git.
class _FakeGitRunner extends GitRunner {
  final String? hash;
  final List<String>? changedFiles;
  final bool notGitRepo;

  _FakeGitRunner({this.hash, this.changedFiles, this.notGitRepo = false});

  @override
  Future<String?> currentHash(String workspaceRoot) async {
    if (notGitRepo) return null;
    return hash;
  }

  @override
  Future<List<String>> changedFilesSince(
    String workspaceRoot,
    String baseHash,
  ) async {
    if (notGitRepo || changedFiles == null) return [];
    return changedFiles!;
  }
}
