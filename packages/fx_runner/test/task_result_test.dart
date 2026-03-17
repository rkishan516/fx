import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('TaskResult', () {
    test('success result', () {
      final result = TaskResult(
        projectName: 'my_lib',
        targetName: 'test',
        status: TaskStatus.success,
        exitCode: 0,
        stdout: 'All tests passed',
        stderr: '',
        duration: const Duration(milliseconds: 500),
      );
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.projectName, 'my_lib');
    });

    test('failure result', () {
      final result = TaskResult(
        projectName: 'my_lib',
        targetName: 'test',
        status: TaskStatus.failure,
        exitCode: 1,
        stdout: '',
        stderr: 'Test failed',
        duration: const Duration(seconds: 1),
      );
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('skipped result has isSuccess false', () {
      final result = TaskResult.skipped(
        projectName: 'pkg',
        targetName: 'test',
        reason: 'dep failed',
      );
      expect(result.status, TaskStatus.skipped);
      expect(result.isSuccess, isFalse);
    });

    test('cached result', () {
      final result = TaskResult(
        projectName: 'pkg',
        targetName: 'test',
        status: TaskStatus.cached,
        exitCode: 0,
        stdout: 'from cache',
        stderr: '',
        duration: Duration.zero,
      );
      expect(result.status, TaskStatus.cached);
      expect(result.isSuccess, isTrue);
    });

    test('isCached returns true only for cached status', () {
      final cached = TaskResult(
        projectName: 'pkg',
        targetName: 'test',
        status: TaskStatus.cached,
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );
      final success = TaskResult(
        projectName: 'pkg',
        targetName: 'test',
        status: TaskStatus.success,
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );
      expect(cached.isCached, isTrue);
      expect(success.isCached, isFalse);
    });

    test('isSkipped returns true only for skipped status', () {
      final skipped = TaskResult.skipped(
        projectName: 'pkg',
        targetName: 'test',
        reason: 'dep failed',
      );
      final success = TaskResult(
        projectName: 'pkg',
        targetName: 'test',
        status: TaskStatus.success,
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );
      expect(skipped.isSkipped, isTrue);
      expect(success.isSkipped, isFalse);
    });

    test('skipped result has skipReason', () {
      final result = TaskResult.skipped(
        projectName: 'pkg',
        targetName: 'test',
        reason: 'dependency failed',
      );
      expect(result.skipReason, equals('dependency failed'));
    });

    test('skipped result has exitCode -1', () {
      final result = TaskResult.skipped(
        projectName: 'pkg',
        targetName: 'test',
        reason: 'reason',
      );
      expect(result.exitCode, equals(-1));
    });

    test('skipped result has zero duration', () {
      final result = TaskResult.skipped(
        projectName: 'pkg',
        targetName: 'test',
        reason: 'reason',
      );
      expect(result.duration, equals(Duration.zero));
    });

    test('toString includes project and target name', () {
      final result = TaskResult(
        projectName: 'my_pkg',
        targetName: 'build',
        status: TaskStatus.success,
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );
      expect(result.toString(), contains('my_pkg'));
      expect(result.toString(), contains('build'));
      expect(result.toString(), contains('success'));
    });

    test('failure result has isSuccess false and isFailure true', () {
      final result = TaskResult(
        projectName: 'pkg',
        targetName: 'test',
        status: TaskStatus.failure,
        exitCode: 2,
        stdout: '',
        stderr: 'error',
        duration: const Duration(seconds: 1),
      );
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.isSkipped, isFalse);
      expect(result.isCached, isFalse);
    });

    test('success result is not failure, skipped, or cached', () {
      final result = TaskResult(
        projectName: 'pkg',
        targetName: 'test',
        status: TaskStatus.success,
        exitCode: 0,
        stdout: 'ok',
        stderr: '',
        duration: Duration.zero,
      );
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.isSkipped, isFalse);
      expect(result.isCached, isFalse);
    });
  });
}
