/// Status of a task execution.
enum TaskStatus {
  success,
  failure,
  skipped,
  cached,

  /// Task was started as a continuous (long-running) process without awaiting
  /// its completion. The process runs until shutdown() is called.
  continuous,
}

/// Result of running a single target on a single project.
class TaskResult {
  final String projectName;
  final String targetName;
  final TaskStatus status;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final String? skipReason;

  const TaskResult({
    required this.projectName,
    required this.targetName,
    required this.status,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.skipReason,
  });

  factory TaskResult.skipped({
    required String projectName,
    required String targetName,
    required String reason,
  }) {
    return TaskResult(
      projectName: projectName,
      targetName: targetName,
      status: TaskStatus.skipped,
      exitCode: -1,
      stdout: '',
      stderr: '',
      duration: Duration.zero,
      skipReason: reason,
    );
  }

  bool get isSuccess =>
      status == TaskStatus.success || status == TaskStatus.cached;
  bool get isFailure => status == TaskStatus.failure;
  bool get isSkipped => status == TaskStatus.skipped;
  bool get isCached => status == TaskStatus.cached;
  bool get isContinuous => status == TaskStatus.continuous;

  @override
  String toString() => 'TaskResult($projectName:$targetName, $status)';
}
