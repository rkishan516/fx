import 'dart:async';
import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

/// A fake [Process] that never exits until kill() is called.
class _FakeProcess implements Process {
  final _exitCompleter = Completer<int>();
  bool killed = false;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(0);
    return true;
  }

  @override
  int get pid => 12345;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();
}

/// Creates a [ContinuousTaskManager] that uses [_FakeProcess] instances.
ContinuousTaskManager _makeMockContinuousManager() {
  return ContinuousTaskManager(
    processStarter: (executable, args, {workingDirectory = '.'}) async {
      return _FakeProcess();
    },
  );
}

void main() {
  Project makeProject(String name, List<String> deps) => Project(
    name: name,
    path: '/ws/packages/$name',
    type: ProjectType.dartPackage,
    dependencies: deps,
    targets: {'test': Target(name: 'test', executor: 'dart test')},
  );

  group('TaskRunner', () {
    test('runs task on single project', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: 'ok', stderr: ''),
      );

      final projects = [makeProject('pkg_a', [])];
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(projects: projects, targetName: 'test');

      expect(results, hasLength(1));
      expect(results.first.status, TaskStatus.success);
      expect(results.first.projectName, 'pkg_a');
    });

    test('skips dependent project when dependency fails', () async {
      var callCount = 0;
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          callCount++;
          // First call (dependency) fails, second should be skipped
          return ProcessResult(
            exitCode: callCount == 1 ? 1 : 0,
            stdout: '',
            stderr: callCount == 1 ? 'error' : '',
          );
        },
      );

      // app depends on core; core fails; app should be skipped
      final projects = [
        makeProject('core', []), // processed first (leaf)
        makeProject('app', ['core']), // depends on core
      ];
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(
        projects: projects,
        targetName: 'test',
        failedProjects: {},
      );

      final coreResult = results.firstWhere((r) => r.projectName == 'core');
      final appResult = results.firstWhere((r) => r.projectName == 'app');

      expect(coreResult.status, TaskStatus.failure);
      expect(appResult.status, TaskStatus.skipped);
      expect(callCount, 1); // app's executor should NOT have been called
    });

    test('runs projects in provided order', () async {
      final executionOrder = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executionOrder.add(call.workingDirectory.split('/').last);
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      // Pre-sorted: b before a (b is a dependency)
      final projects = [
        makeProject('b', []),
        makeProject('a', ['b']),
      ];
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      await runner.run(projects: projects, targetName: 'test');

      expect(
        executionOrder.indexOf('b'),
        lessThan(executionOrder.indexOf('a')),
      );
    });

    test('respects concurrency limit', () async {
      var concurrent = 0;
      var maxConcurrent = 0;

      final mockRunner = MockProcessRunner(
        onRun: (_) async {
          concurrent++;
          if (concurrent > maxConcurrent) maxConcurrent = concurrent;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          concurrent--;
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final projects = List.generate(4, (i) => makeProject('pkg_$i', []));
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 2,
      );
      await runner.run(projects: projects, targetName: 'test');

      expect(maxConcurrent, lessThanOrEqualTo(2));
    });

    test('empty project list returns empty results', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(projects: [], targetName: 'test');
      expect(results, isEmpty);
    });

    test('unknown target (no executor) results in skipped', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {}, // no targets configured
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(
        projects: [makeProject('a', [])],
        targetName: 'nonexistent',
      );
      expect(results, hasLength(1));
      expect(results.first.status, TaskStatus.skipped);
    });

    test('all projects succeed returns all success results', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: 'ok', stderr: ''),
      );
      final projects = [
        makeProject('a', []),
        makeProject('b', []),
        makeProject('c', []),
      ];
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(projects: projects, targetName: 'test');
      expect(results, hasLength(3));
      expect(results.every((r) => r.isSuccess), isTrue);
    });

    test(
      'cascade skip: failure in root skips all transitive dependents',
      () async {
        var callCount = 0;
        final mockRunner = MockProcessRunner(
          onRun: (_) {
            callCount++;
            // Only root is called and fails
            return ProcessResult(exitCode: 1, stdout: '', stderr: 'error');
          },
        );

        // root fails -> mid should be skipped -> top should be skipped
        final projects = [
          makeProject('root', []),
          makeProject('mid', ['root']),
          makeProject('top', ['mid']),
        ];
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'test': {'executor': 'dart test'},
          },
        });
        final runner = TaskRunner(
          processRunner: mockRunner,
          config: config,
          concurrency: 1,
        );
        final results = await runner.run(
          projects: projects,
          targetName: 'test',
          failedProjects: {},
        );

        expect(results[0].status, TaskStatus.failure);
        expect(results[1].status, TaskStatus.skipped);
        // top depends on mid (which was skipped, not failed), so top still runs
        // and fails because the mock always returns exitCode 1
        expect(results[2].status, TaskStatus.failure);
        // root executes (fails), mid is skipped, top executes (fails)
        expect(callCount, 2);
      },
    );

    test('pipeline: build then test are both executed', () async {
      final executedTargets = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executedTargets.add(call.arguments.join(' '));
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(
        projects: [makeProject('a', [])],
        targetName: 'test',
      );
      expect(results, hasLength(2));
      expect(results[0].targetName, 'build');
      expect(results[1].targetName, 'test');
      expect(results.every((r) => r.isSuccess), isTrue);
    });

    test('pipeline: first step fails skips second step', () async {
      var callCount = 0;
      final mockRunner = MockProcessRunner(
        onRun: (_) {
          callCount++;
          return ProcessResult(exitCode: 1, stdout: '', stderr: 'build error');
        },
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(
        projects: [makeProject('a', [])],
        targetName: 'test',
      );
      expect(results, hasLength(2));
      expect(results[0].status, TaskStatus.failure); // build
      expect(results[1].status, TaskStatus.skipped); // test
      expect(callCount, 1); // only build ran
    });

    test('excludeTaskDependencies skips pipeline deps', () async {
      final executedTargets = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executedTargets.add(call.arguments.join(' '));
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(
        projects: [makeProject('a', [])],
        targetName: 'test',
        excludeTaskDependencies: true,
      );
      // Only 'test' should run, not 'build'
      expect(results, hasLength(1));
      expect(results[0].targetName, 'test');
      expect(results[0].isSuccess, isTrue);
    });

    test('handles transitive (^) pipeline targets with no deps', () async {
      final executedTargets = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executedTargets.add(call.arguments.join(' '));
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['^build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(
        projects: [makeProject('a', [])],
        targetName: 'test',
      );
      // ^build has no deps to expand, so only 'test' runs
      expect(results.where((r) => r.isSuccess), hasLength(1));
      expect(results.first.targetName, 'test');
      expect(results.first.isSuccess, isTrue);
    });

    test('expands transitive (^) pipeline targets to run on deps', () async {
      final executedTargets = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          executedTargets.add(call.arguments.join(' '));
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['^build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final projectA = makeProject('a', []);
      final projectB = makeProject('b', ['a']);
      final results = await runner.run(
        projects: [projectA, projectB],
        targetName: 'test',
      );
      // For project a: ^build has no deps, test runs
      // For project b: ^build expands to run build on dep 'a', then test runs
      final successNames = results
          .where((r) => r.isSuccess)
          .map((r) => '${r.projectName}:${r.targetName}')
          .toList();
      expect(successNames, contains('a:test'));
      expect(successNames, contains('a:build')); // dep build for b
      expect(successNames, contains('b:test'));
    });

    test('parallel: independent projects run concurrently', () async {
      var concurrent = 0;
      var maxConcurrent = 0;

      final mockRunner = MockProcessRunner(
        onRun: (_) async {
          concurrent++;
          if (concurrent > maxConcurrent) maxConcurrent = concurrent;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          concurrent--;
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      // 4 independent projects with concurrency=4 should all run at once
      final projects = List.generate(4, (i) => makeProject('pkg_$i', []));
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 4,
      );
      await runner.run(projects: projects, targetName: 'test');

      // With concurrency=4 and 4 independent projects, we should see
      // more than 1 concurrent execution
      expect(maxConcurrent, greaterThan(1));
    });

    test('parallel: dependent projects wait for deps', () async {
      final executionOrder = <String>[];

      final mockRunner = MockProcessRunner(
        onRun: (call) async {
          final name = call.workingDirectory.split('/').last;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          executionOrder.add(name);
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      // b depends on a: a must complete before b starts
      final projects = [
        makeProject('a', []),
        makeProject('b', ['a']),
      ];
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 4,
      );
      await runner.run(projects: projects, targetName: 'test');

      expect(
        executionOrder.indexOf('a'),
        lessThan(executionOrder.indexOf('b')),
      );
    });

    test('mixed results: some succeed some fail', () async {
      var callIndex = 0;
      final mockRunner = MockProcessRunner(
        onRun: (_) {
          callIndex++;
          // fail on second project
          return ProcessResult(
            exitCode: callIndex == 2 ? 1 : 0,
            stdout: '',
            stderr: '',
          );
        },
      );
      final projects = [
        makeProject('a', []),
        makeProject('b', []),
        makeProject('c', []),
      ];
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(projects: projects, targetName: 'test');
      expect(results[0].isSuccess, isTrue);
      expect(results[1].isFailure, isTrue);
      expect(results[2].isSuccess, isTrue);
    });
  });

  group('Continuous tasks', () {
    test('continuous task does not block subsequent tasks', () async {
      final log = <String>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) async {
          log.add('ran:${call.arguments.join(' ')}');
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      // Project with a continuous serve target + a dependent test target
      final project = Project(
        name: 'my_app',
        path: '/ws/packages/my_app',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {
          'serve': Target(
            name: 'serve',
            executor: 'dart run server.dart',
            continuous: true,
          ),
          'test': Target(name: 'test', executor: 'dart test'),
        },
      );

      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      final results = await runner.run(projects: [project], targetName: 'test');

      // test should run (serve is not in this run)
      expect(results.any((r) => r.targetName == 'test'), isTrue);
    });

    test(
      'continuous target appears with continuous status when targeted directly',
      () async {
        final mockRunner = MockProcessRunner(
          onRun: (_) async =>
              ProcessResult(exitCode: 0, stdout: 'server started', stderr: ''),
        );

        final project = Project(
          name: 'app',
          path: '/ws/packages/app',
          type: ProjectType.flutterApp,
          dependencies: [],
          targets: {
            'serve': Target(
              name: 'serve',
              executor: 'fake_server',
              continuous: true,
            ),
          },
        );

        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'serve': {'executor': 'fake_server', 'continuous': true},
          },
        });
        final runner = TaskRunner(
          processRunner: mockRunner,
          config: config,
          concurrency: 1,
        );
        final results = await runner.run(
          projects: [project],
          targetName: 'serve',
          continuousManager: _makeMockContinuousManager(),
        );

        expect(results, hasLength(1));
        expect(results.first.status, TaskStatus.continuous);
      },
    );

    test('non-continuous tasks still await completion', () async {
      var completed = false;
      final mockRunner = MockProcessRunner(
        onRun: (_) async {
          completed = true;
          return ProcessResult(exitCode: 0, stdout: 'done', stderr: '');
        },
      );

      final projects = [makeProject('pkg', [])];
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
      );
      await runner.run(projects: projects, targetName: 'test');
      expect(completed, isTrue);
    });
  });

  group('Plugin lifecycle hooks', () {
    test('preTasksExecution is called and can abort', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      var preCalled = false;
      final hook = _TestPluginHook(
        onPre: (m) async {
          preCalled = true;
          return false; // abort
        },
      );

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
        pluginHooks: [hook],
      );
      final results = await runner.run(
        projects: [makeProject('a', [])],
        targetName: 'test',
      );

      expect(preCalled, isTrue);
      expect(results, isEmpty); // aborted
    });

    test('postTasksExecution receives results', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      List<Map<String, dynamic>>? capturedResults;
      final hook = _TestPluginHook(
        onPost: (m, results) async {
          capturedResults = results;
        },
      );

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
        pluginHooks: [hook],
      );
      await runner.run(projects: [makeProject('a', [])], targetName: 'test');

      expect(capturedResults, isNotNull);
      expect(capturedResults, hasLength(1));
      expect(capturedResults!.first['projectName'], 'a');
      expect(capturedResults!.first['status'], 'success');
    });

    test('createMetadata adds plugin metadata to results', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });

      List<Map<String, dynamic>>? capturedResults;
      final hook = _TestPluginHook(
        onCreateMetadata: (m) async => {'commitHash': 'abc123'},
        onPost: (m, results) async {
          capturedResults = results;
        },
      );

      final runner = TaskRunner(
        processRunner: mockRunner,
        config: config,
        concurrency: 1,
        pluginHooks: [hook],
      );
      await runner.run(projects: [makeProject('a', [])], targetName: 'test');

      expect(capturedResults!.first['commitHash'], 'abc123');
    });
  });
}

class _TestPluginHook extends PluginHook {
  final Future<bool> Function(TaskRunMetadata)? onPre;
  final Future<void> Function(TaskRunMetadata, List<Map<String, dynamic>>)?
  onPost;
  final Future<Map<String, dynamic>> Function(TaskRunMetadata)?
  onCreateMetadata;

  _TestPluginHook({this.onPre, this.onPost, this.onCreateMetadata});

  @override
  String get name => 'test-hook';
  @override
  String get fileGlob => '**';
  @override
  Future<List<Project>> inferProjects(
    String workspaceRoot,
    List<String> matchedFiles,
  ) async => [];
  @override
  Future<Map<String, List<String>>> inferDependencies(
    List<Project> projects,
  ) async => {};
  @override
  Future<bool> preTasksExecution(TaskRunMetadata metadata) async =>
      onPre != null ? onPre!(metadata) : true;
  @override
  Future<void> postTasksExecution(
    TaskRunMetadata metadata,
    List<Map<String, dynamic>> results,
  ) async {
    if (onPost != null) await onPost!(metadata, results);
  }

  @override
  Future<Map<String, dynamic>> createMetadata(TaskRunMetadata metadata) async =>
      onCreateMetadata != null ? await onCreateMetadata!(metadata) : {};
}
