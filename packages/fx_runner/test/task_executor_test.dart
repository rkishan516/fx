import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('TaskExecutor', () {
    test('executes a simple command via process runner', () async {
      final captured = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          captured.add(call);
          return ProcessResult(exitCode: 0, stdout: 'output', stderr: '');
        },
      );

      final project = Project(
        name: 'my_pkg',
        path: '/workspace/packages/my_pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
      );

      final executor = TaskExecutor(processRunner: mockRunner);
      final result = await executor.execute(
        project: project,
        targetName: 'test',
        executor: 'dart test',
      );

      expect(result.status, TaskStatus.success);
      expect(result.exitCode, 0);
      expect(result.stdout, 'output');
      expect(captured, hasLength(1));
      expect(captured.first.executable, 'dart');
      expect(captured.first.arguments, contains('test'));
      expect(captured.first.workingDirectory, '/workspace/packages/my_pkg');
    });

    test('returns failure on non-zero exit code', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 1, stdout: '', stderr: 'error'),
      );

      final project = Project(
        name: 'pkg',
        path: '/ws/packages/pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );

      final executor = TaskExecutor(processRunner: mockRunner);
      final result = await executor.execute(
        project: project,
        targetName: 'test',
        executor: 'dart test',
      );

      expect(result.status, TaskStatus.failure);
      expect(result.exitCode, 1);
    });

    test('result includes duration', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );

      final project = Project(
        name: 'pkg',
        path: '/ws/packages/pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );

      final executor = TaskExecutor(processRunner: mockRunner);
      final result = await executor.execute(
        project: project,
        targetName: 'build',
        executor: 'dart compile',
      );

      expect(result.duration, isNotNull);
    });

    test('parses multi-argument executor correctly', () async {
      final captured = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          captured.add(call);
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final project = Project(
        name: 'pkg',
        path: '/ws/pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );

      final executor = TaskExecutor(processRunner: mockRunner);
      await executor.execute(
        project: project,
        targetName: 'test',
        executor: 'dart test --coverage --reporter json',
      );

      expect(captured.first.executable, equals('dart'));
      expect(
        captured.first.arguments,
        equals(['test', '--coverage', '--reporter', 'json']),
      );
    });

    test('captures stderr from failed process', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) =>
            ProcessResult(exitCode: 1, stdout: '', stderr: 'compilation error'),
      );

      final project = Project(
        name: 'pkg',
        path: '/ws/pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );

      final executor = TaskExecutor(processRunner: mockRunner);
      final result = await executor.execute(
        project: project,
        targetName: 'build',
        executor: 'dart compile exe',
      );

      expect(result.stderr, equals('compilation error'));
      expect(result.status, TaskStatus.failure);
    });

    test('sets working directory to project path', () async {
      final captured = <ProcessCall>[];
      final mockRunner = MockProcessRunner(
        onRun: (call) {
          captured.add(call);
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final project = Project(
        name: 'my_app',
        path: '/workspace/apps/my_app',
        type: ProjectType.flutterApp,
        dependencies: [],
        targets: {},
      );

      final executor = TaskExecutor(processRunner: mockRunner);
      await executor.execute(
        project: project,
        targetName: 'test',
        executor: 'flutter test',
      );

      expect(captured.first.workingDirectory, equals('/workspace/apps/my_app'));
    });

    test('result projectName and targetName match input', () async {
      final mockRunner = MockProcessRunner(
        onRun: (_) => ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      );

      final project = Project(
        name: 'specific_pkg',
        path: '/ws/specific_pkg',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
      );

      final executor = TaskExecutor(processRunner: mockRunner);
      final result = await executor.execute(
        project: project,
        targetName: 'analyze',
        executor: 'dart analyze',
      );

      expect(result.projectName, equals('specific_pkg'));
      expect(result.targetName, equals('analyze'));
    });
  });
}
