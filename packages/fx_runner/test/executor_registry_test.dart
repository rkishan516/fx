import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

class _MockExecutorPlugin extends ExecutorPlugin {
  @override
  final String name;
  @override
  String get description => 'Mock executor for testing';

  final TaskResult Function(Project, Target)? onExecute;

  _MockExecutorPlugin(this.name, {this.onExecute});

  @override
  Future<TaskResult> execute({
    required Project project,
    required Target target,
    required Map<String, dynamic> options,
    required String workspaceRoot,
  }) async {
    if (onExecute != null) return onExecute!(project, target);
    return TaskResult(
      projectName: project.name,
      targetName: target.name,
      status: TaskStatus.success,
      exitCode: 0,
      stdout: 'Plugin $name executed',
      stderr: '',
      duration: Duration.zero,
    );
  }
}

void main() {
  Project makeProject(String name) => Project(
    name: name,
    path: '/workspace/packages/$name',
    type: ProjectType.dartPackage,
    dependencies: [],
    targets: {},
    tags: [],
  );

  group('ExecutorRegistry', () {
    test('register and get a plugin', () {
      final registry = ExecutorRegistry();
      final plugin = _MockExecutorPlugin('coverage');
      registry.register(plugin);

      expect(registry.get('coverage'), same(plugin));
      expect(registry.names, ['coverage']);
    });

    test('returns null for unregistered plugin', () {
      final registry = ExecutorRegistry();
      expect(registry.get('nonexistent'), isNull);
    });

    test('register overwrites existing plugin', () {
      final registry = ExecutorRegistry();
      registry.register(_MockExecutorPlugin('test'));
      final replacement = _MockExecutorPlugin('test');
      registry.register(replacement);

      expect(registry.get('test'), same(replacement));
      expect(registry.names, hasLength(1));
    });

    test('isPluginExecutor detects plugin: prefix', () {
      expect(ExecutorRegistry.isPluginExecutor('plugin:coverage'), isTrue);
      expect(ExecutorRegistry.isPluginExecutor('dart test'), isFalse);
      expect(ExecutorRegistry.isPluginExecutor('plugin:'), isTrue);
    });

    test('extractPluginName extracts name after prefix', () {
      expect(ExecutorRegistry.extractPluginName('plugin:coverage'), 'coverage');
      expect(ExecutorRegistry.extractPluginName('plugin:my-tool'), 'my-tool');
    });
  });

  group('TaskExecutor with plugins', () {
    test('routes plugin: executor to registered plugin', () async {
      final registry = ExecutorRegistry();
      registry.register(_MockExecutorPlugin('coverage'));

      final executor = TaskExecutor(
        processRunner: MockProcessRunner(
          onRun: (_) => throw StateError('Should not be called'),
        ),
        executorRegistry: registry,
      );

      final project = makeProject('my_pkg');
      final result = await executor.execute(
        project: project,
        targetName: 'test',
        executor: 'plugin:coverage',
      );

      expect(result.status, TaskStatus.success);
      expect(result.stdout, contains('Plugin coverage'));
    });

    test('returns failure for unregistered plugin', () async {
      final registry = ExecutorRegistry();

      final executor = TaskExecutor(
        processRunner: MockProcessRunner(
          onRun: (_) => throw StateError('Should not be called'),
        ),
        executorRegistry: registry,
      );

      final result = await executor.execute(
        project: makeProject('my_pkg'),
        targetName: 'test',
        executor: 'plugin:nonexistent',
      );

      expect(result.status, TaskStatus.failure);
      expect(result.stderr, contains('not found'));
    });

    test('plain string executor still uses process runner', () async {
      var processCalled = false;
      final executor = TaskExecutor(
        processRunner: MockProcessRunner(
          onRun: (call) {
            processCalled = true;
            expect(call.executable, 'dart');
            expect(call.arguments, ['test']);
            return ProcessResult(exitCode: 0, stdout: 'ok', stderr: '');
          },
        ),
      );

      final result = await executor.execute(
        project: makeProject('my_pkg'),
        targetName: 'test',
        executor: 'dart test',
      );

      expect(processCalled, isTrue);
      expect(result.status, TaskStatus.success);
    });

    test('plugin receives target options', () async {
      final registry = ExecutorRegistry();
      Map<String, dynamic>? receivedOptions;
      registry.register(
        _MockExecutorPlugin(
          'custom',
          onExecute: (project, target) {
            receivedOptions = target.options;
            return TaskResult(
              projectName: project.name,
              targetName: target.name,
              status: TaskStatus.success,
              exitCode: 0,
              stdout: '',
              stderr: '',
              duration: Duration.zero,
            );
          },
        ),
      );

      final project = Project(
        name: 'my_pkg',
        path: '/workspace/packages/my_pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {
          'test': const Target(
            name: 'test',
            executor: 'plugin:custom',
            options: {'verbose': true, 'reporter': 'json'},
          ),
        },
        tags: [],
      );

      final executor = TaskExecutor(
        processRunner: MockProcessRunner(
          onRun: (_) => throw StateError('Should not be called'),
        ),
        executorRegistry: registry,
      );

      await executor.execute(
        project: project,
        targetName: 'test',
        executor: 'plugin:custom',
      );

      expect(receivedOptions, {'verbose': true, 'reporter': 'json'});
    });
  });
}
