import 'package:fx_runner/fx_runner.dart';

/// Compact TUI-style output for task execution.
///
/// Provides a summary-oriented view similar to Nx's `--output-style=compact`.
/// Shows running/completed/failed counts and only prints output on failure.
class TuiFormatter {
  final StringSink sink;

  TuiFormatter(this.sink);

  /// Print a compact summary line for each task result.
  void writeTaskResult(TaskResult result) {
    final icon = switch (result.status) {
      TaskStatus.success => '\x1B[32m✓\x1B[0m',
      TaskStatus.cached => '\x1B[36m●\x1B[0m',
      TaskStatus.failure => '\x1B[31m✗\x1B[0m',
      TaskStatus.skipped => '\x1B[33m○\x1B[0m',
      TaskStatus.continuous => '\x1B[34m~\x1B[0m',
    };
    final dur = '${result.duration.inMilliseconds}ms';
    sink.writeln('  $icon ${result.projectName}:${result.targetName} ($dur)');

    // Show output only on failure
    if (result.isFailure) {
      if (result.stderr.isNotEmpty) {
        for (final line in result.stderr.split('\n').take(10)) {
          sink.writeln('    $line');
        }
      }
    }
  }

  /// Print a final summary of all results.
  void writeSummary(List<TaskResult> results, String targetName) {
    final success = results.where((r) => r.isSuccess).length;
    final failed = results.where((r) => r.isFailure).length;
    final skipped = results.where((r) => r.isSkipped).length;

    sink.writeln('');
    sink.write('  $targetName: ');
    final parts = <String>[];
    if (success > 0) parts.add('\x1B[32m$success passed\x1B[0m');
    if (failed > 0) parts.add('\x1B[31m$failed failed\x1B[0m');
    if (skipped > 0) parts.add('\x1B[33m$skipped skipped\x1B[0m');
    sink.writeln(parts.join(', '));
  }
}
