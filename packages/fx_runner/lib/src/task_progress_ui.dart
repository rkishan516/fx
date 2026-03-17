import 'dart:async';
import 'dart:io';

import 'task_result.dart';

/// Live terminal UI for task execution progress.
///
/// Displays a spinner + status per project during execution.
/// Uses ANSI escape codes for in-place line updates.
class TaskProgressUI {
  final StringSink _sink;
  final bool _isTerminal;
  final Map<String, _TaskStatus> _tasks = {};
  Timer? _timer;
  int _spinnerFrame = 0;

  static const _spinnerChars = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  TaskProgressUI({StringSink? sink})
    : _sink = sink ?? stdout,
      _isTerminal = sink == null && stdout.hasTerminal;

  /// Register a project as pending.
  void addProject(String name) {
    _tasks[name] = _TaskStatus(name: name, state: _State.pending);
  }

  /// Mark a project as running.
  void markRunning(String name) {
    _tasks[name]?.state = _State.running;
    _tasks[name]?.startTime = DateTime.now();
    _render();
  }

  /// Mark a project as completed with result.
  void markComplete(String name, TaskResult result) {
    final task = _tasks[name];
    if (task == null) return;
    task.state = result.isSuccess
        ? _State.success
        : result.isSkipped
        ? _State.skipped
        : _State.failed;
    task.duration = result.duration;
    _render();
  }

  /// Start the spinner animation timer.
  void start() {
    if (!_isTerminal) return;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _spinnerFrame = (_spinnerFrame + 1) % _spinnerChars.length;
      _render();
    });
  }

  /// Stop the spinner and print final summary.
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_isTerminal) {
      // Clear the live display lines
      _clearLines();
    }
  }

  /// Print a static summary (for non-terminal or final output).
  void printSummary() {
    final succeeded = _tasks.values
        .where((t) => t.state == _State.success)
        .length;
    final failed = _tasks.values.where((t) => t.state == _State.failed).length;
    final skipped = _tasks.values
        .where((t) => t.state == _State.skipped)
        .length;

    _sink.writeln('');
    _sink.writeln(
      '  $succeeded succeeded, $failed failed, $skipped skipped '
      '(${_tasks.length} total)',
    );

    if (failed > 0) {
      _sink.writeln('');
      _sink.writeln('  Failed:');
      for (final task in _tasks.values.where((t) => t.state == _State.failed)) {
        _sink.writeln('    ✗ ${task.name}');
      }
    }
  }

  /// Render current state to terminal.
  void _render() {
    if (!_isTerminal) return;

    final spinner = _spinnerChars[_spinnerFrame];
    final buf = StringBuffer();

    // Move cursor up to overwrite previous render
    if (_tasks.isNotEmpty) {
      buf.write('\x1B[${_tasks.length}A'); // Move up N lines
      buf.write('\x1B[0J'); // Clear from cursor to end
    }

    for (final task in _tasks.values) {
      switch (task.state) {
        case _State.pending:
          buf.writeln('  ○ ${task.name}');
        case _State.running:
          final elapsed = DateTime.now().difference(task.startTime!);
          buf.writeln('  $spinner ${task.name} (${_formatDuration(elapsed)})');
        case _State.success:
          buf.writeln(
            '  \x1B[32m✓\x1B[0m ${task.name} (${_formatDuration(task.duration!)})',
          );
        case _State.failed:
          buf.writeln(
            '  \x1B[31m✗\x1B[0m ${task.name} (${_formatDuration(task.duration!)})',
          );
        case _State.skipped:
          buf.writeln('  \x1B[33m⊘\x1B[0m ${task.name} (skipped)');
      }
    }

    _sink.write(buf.toString());
  }

  void _clearLines() {
    if (_tasks.isNotEmpty) {
      _sink.write('\x1B[${_tasks.length}A');
      _sink.write('\x1B[0J');
    }
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 1) return '${d.inMilliseconds}ms';
    if (d.inMinutes < 1) {
      return '${d.inSeconds}.${(d.inMilliseconds % 1000) ~/ 100}s';
    }
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

enum _State { pending, running, success, failed, skipped }

class _TaskStatus {
  final String name;
  _State state;
  DateTime? startTime;
  Duration? duration;

  _TaskStatus({required this.name, required this.state});
}
