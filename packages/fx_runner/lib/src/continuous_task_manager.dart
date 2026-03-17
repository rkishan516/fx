import 'dart:async';
import 'dart:io';

import 'task_result.dart';

/// Function type for starting a process — injectable for testing.
typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String workingDirectory,
    });

Future<Process> _defaultProcessStarter(
  String executable,
  List<String> arguments, {
  String workingDirectory = '.',
}) {
  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
}

/// A running continuous process entry.
class _ContinuousEntry {
  final String projectName;
  final String targetName;
  final Process process;
  final DateTime startedAt;

  _ContinuousEntry({
    required this.projectName,
    required this.targetName,
    required this.process,
    required this.startedAt,
  });
}

/// Manages long-running continuous task processes.
///
/// Continuous tasks (e.g. dev servers) are started without awaiting their
/// completion. This manager tracks them, monitors their health, and shuts
/// them down cleanly when the run is complete.
///
/// Shutdown sequence: SIGTERM → wait 3s → SIGKILL.
class ContinuousTaskManager {
  final ProcessStarter _processStarter;
  final _entries = <_ContinuousEntry>[];

  ContinuousTaskManager({ProcessStarter? processStarter})
    : _processStarter = processStarter ?? _defaultProcessStarter;

  /// Start a continuous process and track it.
  ///
  /// Returns a [TaskResult] with [TaskStatus.continuous] immediately.
  /// The process runs in the background; its output is prefixed with
  /// `[continuous:projectName:targetName]`.
  Future<TaskResult> start({
    required String projectName,
    required String targetName,
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    final start = DateTime.now();
    final label = '[continuous:$projectName:$targetName]';

    final process = await _processStarter(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );

    // Prefix and forward output
    process.stdout
        .transform(const SystemEncoding().decoder)
        .listen((line) => stdout.write('$label $line'));
    process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((line) => stderr.write('$label $line'));

    _entries.add(
      _ContinuousEntry(
        projectName: projectName,
        targetName: targetName,
        process: process,
        startedAt: start,
      ),
    );

    return TaskResult(
      projectName: projectName,
      targetName: targetName,
      status: TaskStatus.continuous,
      exitCode: 0,
      stdout: '',
      stderr: '',
      duration: DateTime.now().difference(start),
    );
  }

  /// Returns any entries whose process has already exited with a non-zero code.
  Future<List<TaskResult>> collectCrashes() async {
    final crashed = <TaskResult>[];
    for (final entry in List.of(_entries)) {
      // Non-blocking exit code check using a timeout
      final exitCode = await entry.process.exitCode.timeout(
        Duration.zero,
        onTimeout: () => -999,
      );
      if (exitCode != -999 && exitCode != 0) {
        crashed.add(
          TaskResult(
            projectName: entry.projectName,
            targetName: entry.targetName,
            status: TaskStatus.failure,
            exitCode: exitCode,
            stdout: '',
            stderr: 'Continuous task crashed with exit code $exitCode',
            duration: DateTime.now().difference(entry.startedAt),
          ),
        );
        _entries.remove(entry);
      }
    }
    return crashed;
  }

  /// Shut down all running continuous processes.
  ///
  /// Sends SIGTERM to each process, then waits up to [timeout] for clean exit.
  /// Any processes still alive after timeout receive SIGKILL.
  Future<void> shutdown({Duration timeout = const Duration(seconds: 3)}) async {
    if (_entries.isEmpty) return;

    // Send SIGTERM to all
    for (final entry in _entries) {
      entry.process.kill(ProcessSignal.sigterm);
    }

    // Wait for processes to exit, or force-kill after timeout
    await Future.wait(
      _entries.map((entry) async {
        try {
          await entry.process.exitCode.timeout(timeout);
        } on TimeoutException {
          entry.process.kill(ProcessSignal.sigkill);
          try {
            await entry.process.exitCode.timeout(const Duration(seconds: 2));
          } catch (_) {
            // best effort
          }
        }
      }),
    );

    _entries.clear();
  }

  /// Number of currently tracked continuous processes.
  int get count => _entries.length;
}
