import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessCall', () {
    test('stores executable, arguments, and workingDirectory', () {
      const call = ProcessCall(
        executable: 'dart',
        arguments: ['test', '--coverage'],
        workingDirectory: '/ws/packages/pkg',
      );
      expect(call.executable, equals('dart'));
      expect(call.arguments, equals(['test', '--coverage']));
      expect(call.workingDirectory, equals('/ws/packages/pkg'));
    });

    test('environment defaults to null', () {
      const call = ProcessCall(
        executable: 'dart',
        arguments: [],
        workingDirectory: '.',
      );
      expect(call.environment, isNull);
    });

    test('stores environment when provided', () {
      const call = ProcessCall(
        executable: 'dart',
        arguments: [],
        workingDirectory: '.',
        environment: {'DART_VM_OPTIONS': '--enable-asserts'},
      );
      expect(
        call.environment,
        containsPair('DART_VM_OPTIONS', '--enable-asserts'),
      );
    });
  });

  group('ProcessResult', () {
    test('stores exitCode, stdout, stderr', () {
      const result = ProcessResult(exitCode: 0, stdout: 'output', stderr: '');
      expect(result.exitCode, equals(0));
      expect(result.stdout, equals('output'));
      expect(result.stderr, equals(''));
    });

    test('non-zero exit code', () {
      const result = ProcessResult(
        exitCode: 127,
        stdout: '',
        stderr: 'command not found',
      );
      expect(result.exitCode, equals(127));
      expect(result.stderr, equals('command not found'));
    });
  });

  group('MockProcessRunner', () {
    test('delegates to onRun callback', () async {
      final calls = <ProcessCall>[];
      final runner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          return ProcessResult(exitCode: 0, stdout: 'mocked', stderr: '');
        },
      );

      final result = await runner.run(
        const ProcessCall(
          executable: 'dart',
          arguments: ['test'],
          workingDirectory: '/ws',
        ),
      );

      expect(calls, hasLength(1));
      expect(calls.first.executable, equals('dart'));
      expect(result.stdout, equals('mocked'));
    });

    test('can return different results per call', () async {
      int count = 0;
      final runner = MockProcessRunner(
        onRun: (_) {
          count++;
          return ProcessResult(
            exitCode: count == 1 ? 0 : 1,
            stdout: 'call $count',
            stderr: '',
          );
        },
      );

      final call = const ProcessCall(
        executable: 'dart',
        arguments: ['test'],
        workingDirectory: '.',
      );

      final r1 = await runner.run(call);
      final r2 = await runner.run(call);

      expect(r1.exitCode, equals(0));
      expect(r2.exitCode, equals(1));
    });

    test('supports async onRun callback', () async {
      final runner = MockProcessRunner(
        onRun: (call) async {
          return ProcessResult(exitCode: 0, stdout: 'async result', stderr: '');
        },
      );

      final result = await runner.run(
        const ProcessCall(
          executable: 'echo',
          arguments: ['hi'],
          workingDirectory: '.',
        ),
      );

      expect(result.stdout, equals('async result'));
    });
  });
}
