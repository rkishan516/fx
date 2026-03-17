import 'dart:async';
import 'dart:io' as io;

/// Information about a process call.
class ProcessCall {
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String>? environment;

  const ProcessCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    this.environment,
  });
}

/// Result from running a process.
class ProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const ProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

/// Abstract interface for running system processes.
///
/// Allows mocking in tests without spawning real processes.
abstract class ProcessRunner {
  Future<ProcessResult> run(ProcessCall call);
}

/// Production implementation using [io.Process].
class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(ProcessCall call) async {
    final result = await io.Process.run(
      call.executable,
      call.arguments,
      workingDirectory: call.workingDirectory,
      environment: call.environment,
    );
    return ProcessResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString().trim(),
      stderr: result.stderr.toString().trim(),
    );
  }
}

/// Mock process runner for testing.
class MockProcessRunner implements ProcessRunner {
  final FutureOr<ProcessResult> Function(ProcessCall) onRun;

  const MockProcessRunner({required this.onRun});

  @override
  Future<ProcessResult> run(ProcessCall call) async => onRun(call);
}
