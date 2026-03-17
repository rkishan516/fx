import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('TaskPartitioner', () {
    final projects = [
      Project(
        name: 'core',
        path: '/core',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
      ),
      Project(
        name: 'utils',
        path: '/utils',
        type: ProjectType.dartPackage,
        dependencies: ['core'],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
      ),
      Project(
        name: 'app',
        path: '/app',
        type: ProjectType.dartPackage,
        dependencies: ['core', 'utils'],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
      ),
      Project(
        name: 'cli',
        path: '/cli',
        type: ProjectType.dartCli,
        dependencies: ['core'],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
      ),
      Project(
        name: 'docs',
        path: '/docs',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
      ),
    ];

    test('partitions projects into N groups', () {
      final partitions = TaskPartitioner.partition(projects, 3);

      expect(partitions, hasLength(3));
      // All projects should be assigned
      final allAssigned = partitions
          .expand((p) => p)
          .map((p) => p.name)
          .toSet();
      expect(allAssigned, hasLength(5));
      expect(allAssigned, containsAll(['core', 'utils', 'app', 'cli', 'docs']));
    });

    test('single partition contains all projects', () {
      final partitions = TaskPartitioner.partition(projects, 1);
      expect(partitions, hasLength(1));
      expect(partitions[0], hasLength(5));
    });

    test('more partitions than projects creates empty partitions', () {
      final partitions = TaskPartitioner.partition(projects, 10);
      expect(partitions, hasLength(10));
      final total = partitions.fold(0, (sum, p) => sum + p.length);
      expect(total, 5);
    });

    test('respects dependencies within partitions', () {
      final partitions = TaskPartitioner.partition(projects, 2);

      for (final partition in partitions) {
        final names = partition.map((p) => p.name).toSet();
        for (final project in partition) {
          // If a dependency is in the same partition, it should come before
          for (final dep in project.dependencies) {
            if (names.contains(dep)) {
              final depIdx = partition.indexWhere((p) => p.name == dep);
              final projIdx = partition.indexWhere(
                (p) => p.name == project.name,
              );
              expect(
                depIdx,
                lessThan(projIdx),
                reason: '${project.name} depends on $dep but $dep comes after',
              );
            }
          }
        }
      }
    });

    test('getPartition returns specific partition by index', () {
      final partitions = TaskPartitioner.partition(projects, 3);
      final p1 = TaskPartitioner.getPartition(projects, 3, 0);
      final p2 = TaskPartitioner.getPartition(projects, 3, 1);

      expect(p1.map((p) => p.name), partitions[0].map((p) => p.name));
      expect(p2.map((p) => p.name), partitions[1].map((p) => p.name));
    });

    test('getPartition throws for invalid index', () {
      expect(
        () => TaskPartitioner.getPartition(projects, 3, 5),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DistributedConfig', () {
    test('parses from YAML-like map', () {
      final config = DistributedConfig(totalWorkers: 4, workerIndex: 1);

      expect(config.totalWorkers, 4);
      expect(config.workerIndex, 1);
    });

    test('validates worker index < total', () {
      expect(
        () => DistributedConfig(totalWorkers: 3, workerIndex: 3),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates positive total', () {
      expect(
        () => DistributedConfig(totalWorkers: 0, workerIndex: 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
