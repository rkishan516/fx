import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('BatchGrouper', () {
    Project project(String name) => Project(
      name: name,
      path: '/workspace/packages/$name',
      type: ProjectType.dartPackage,
      dependencies: [],
      targets: {},
      tags: [],
    );

    test('groups projects with same batchable executor', () {
      final entries = [
        BatchEntry(
          project: project('pkg_a'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
        BatchEntry(
          project: project('pkg_b'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
        BatchEntry(
          project: project('pkg_c'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
      ];

      final groups = BatchGrouper.group(entries);

      expect(groups, hasLength(1));
      expect(groups.first.executor, 'dart test');
      expect(groups.first.projects, hasLength(3));
    });

    test('keeps non-batchable executors as individual groups', () {
      final entries = [
        BatchEntry(
          project: project('pkg_a'),
          target: const Target(
            name: 'compile',
            executor: 'dart compile exe bin/main.dart',
          ),
        ),
        BatchEntry(
          project: project('pkg_b'),
          target: const Target(
            name: 'compile',
            executor: 'dart compile exe bin/main.dart',
          ),
        ),
      ];

      final groups = BatchGrouper.group(entries);

      // dart compile is not in the default batchable list
      expect(groups, hasLength(2));
    });

    test('separates different executors into different groups', () {
      final entries = [
        BatchEntry(
          project: project('pkg_a'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
        BatchEntry(
          project: project('pkg_b'),
          target: const Target(name: 'test', executor: 'flutter test'),
        ),
        BatchEntry(
          project: project('pkg_c'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
      ];

      final groups = BatchGrouper.group(entries);

      expect(groups, hasLength(2));
      final dartGroup = groups.firstWhere((g) => g.executor == 'dart test');
      final flutterGroup = groups.firstWhere(
        (g) => g.executor == 'flutter test',
      );
      expect(dartGroup.projects, hasLength(2));
      expect(flutterGroup.projects, hasLength(1));
    });

    test('respects batchable: false in target options', () {
      final entries = [
        BatchEntry(
          project: project('pkg_a'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
        BatchEntry(
          project: project('pkg_b'),
          target: const Target(
            name: 'test',
            executor: 'dart test',
            options: {'batchable': false},
          ),
        ),
      ];

      final groups = BatchGrouper.group(entries);

      // pkg_a stays in a dart test group, pkg_b is individual
      expect(groups, hasLength(2));
    });

    test('returns empty list for empty input', () {
      final groups = BatchGrouper.group([]);
      expect(groups, isEmpty);
    });

    test('single project with batchable executor stays as single group', () {
      final entries = [
        BatchEntry(
          project: project('pkg_a'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
      ];

      final groups = BatchGrouper.group(entries);
      expect(groups, hasLength(1));
      expect(groups.first.projects, hasLength(1));
    });

    test('supports custom batchable executors set', () {
      final entries = [
        BatchEntry(
          project: project('pkg_a'),
          target: const Target(name: 'build', executor: 'custom_tool build'),
        ),
        BatchEntry(
          project: project('pkg_b'),
          target: const Target(name: 'build', executor: 'custom_tool build'),
        ),
      ];

      final groups = BatchGrouper.group(
        entries,
        batchableExecutors: {'custom_tool build'},
      );

      expect(groups, hasLength(1));
      expect(groups.first.projects, hasLength(2));
    });

    test('mixed batchable and non-batchable in same run', () {
      final entries = [
        BatchEntry(
          project: project('pkg_a'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
        BatchEntry(
          project: project('pkg_b'),
          target: const Target(name: 'test', executor: 'dart test'),
        ),
        BatchEntry(
          project: project('pkg_c'),
          target: const Target(
            name: 'build',
            executor: 'dart compile exe bin/main.dart',
          ),
        ),
      ];

      final groups = BatchGrouper.group(entries);

      expect(groups, hasLength(2));
      final batchGroup = groups.firstWhere((g) => g.projects.length > 1);
      expect(batchGroup.executor, 'dart test');
      expect(batchGroup.projects.map((p) => p.name), ['pkg_a', 'pkg_b']);
    });
  });
}
