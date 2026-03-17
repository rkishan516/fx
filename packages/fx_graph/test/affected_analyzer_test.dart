import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:test/test.dart';

void main() {
  Project makeProject(String name, List<String> deps, String path) => Project(
    name: name,
    path: path,
    type: ProjectType.dartPackage,
    dependencies: deps,
    targets: {},
  );

  group('AffectedAnalyzer', () {
    final core = makeProject('core', [], '/ws/packages/core');
    final utils = makeProject('utils', [], '/ws/packages/utils');
    final app = makeProject('app', ['core'], '/ws/apps/app');
    final allProjects = [core, utils, app];

    test('changed file in core affects core and its dependents', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/packages/core/lib/src/model.dart'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected.map((p) => p.name), containsAll(['core', 'app']));
      // utils is not affected
      expect(affected.map((p) => p.name), isNot(contains('utils')));
    });

    test('root-level file change affects all projects', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/analysis_options.yaml'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(
        affected.map((p) => p.name),
        containsAll(['core', 'utils', 'app']),
      );
    });

    test('no changed files returns empty affected list', () {
      final graph = ProjectGraph.build(allProjects);
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: [],
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected, isEmpty);
    });

    test('transitive: changed utils affects utils only (no dependents)', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/packages/utils/lib/utils.dart'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected.map((p) => p.name), contains('utils'));
      expect(affected.map((p) => p.name), isNot(contains('app')));
      expect(affected.map((p) => p.name), isNot(contains('core')));
    });

    test('changes in multiple projects affects both and their dependents', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = [
        '/ws/packages/core/lib/model.dart',
        '/ws/packages/utils/lib/utils.dart',
      ];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      // core changed -> app affected; utils changed -> utils affected
      expect(
        affected.map((p) => p.name),
        containsAll(['core', 'utils', 'app']),
      );
    });

    test('deep transitive chain: change in leaf affects root', () {
      // chain: app -> mid -> leaf
      final leaf = makeProject('leaf', [], '/ws/packages/leaf');
      final mid = makeProject('mid', ['leaf'], '/ws/packages/mid');
      final top = makeProject('top', ['mid'], '/ws/packages/top');
      final projects = [leaf, mid, top];
      final graph = ProjectGraph.build(projects);
      final changedFiles = ['/ws/packages/leaf/lib/leaf.dart'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: projects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected.map((p) => p.name), containsAll(['leaf', 'mid', 'top']));
    });

    test('file outside workspace root is not considered affected', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/other/place/file.dart'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected, isEmpty);
    });

    test('pubspec.yaml at root level affects all projects', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/pubspec.yaml'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected, hasLength(allProjects.length));
    });

    test('analysis_options.yaml at root affects all projects', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/analysis_options.yaml'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected, hasLength(allProjects.length));
    });

    test('changed test file inside project only affects that project', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/packages/utils/test/utils_test.dart'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected.map((p) => p.name), equals(['utils']));
    });

    test('pubspec.lock change affects all projects by default', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/pubspec.lock'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
      );
      expect(affected, hasLength(allProjects.length));
    });

    test('pubspec.lock change ignored when lockfileAffectsAll is none', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = ['/ws/pubspec.lock'];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
        lockfileAffectsAll: 'none',
      );
      expect(affected, isEmpty);
    });

    test('lock file + source change with none: only source affects', () {
      final graph = ProjectGraph.build(allProjects);
      final changedFiles = [
        '/ws/pubspec.lock',
        '/ws/packages/core/lib/core.dart',
      ];
      final affected = AffectedAnalyzer.computeAffected(
        changedFiles: changedFiles,
        projects: allProjects,
        graph: graph,
        workspaceRoot: '/ws',
        lockfileAffectsAll: 'none',
      );
      expect(affected.map((p) => p.name), containsAll(['core', 'app']));
      expect(affected.map((p) => p.name), isNot(contains('utils')));
    });
  });
}
