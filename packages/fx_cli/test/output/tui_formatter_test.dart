import 'package:fx_cli/src/output/tui_formatter.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('TuiFormatter', () {
    late StringBuffer output;
    late TuiFormatter tui;

    setUp(() {
      output = StringBuffer();
      tui = TuiFormatter(output);
    });

    test('writeTaskResult shows success icon', () {
      tui.writeTaskResult(
        TaskResult(
          projectName: 'pkg_a',
          targetName: 'test',
          status: TaskStatus.success,
          exitCode: 0,
          stdout: '',
          stderr: '',
          duration: Duration(milliseconds: 42),
        ),
      );
      expect(output.toString(), contains('✓'));
      expect(output.toString(), contains('pkg_a:test'));
      expect(output.toString(), contains('42ms'));
    });

    test('writeTaskResult shows failure icon with stderr', () {
      tui.writeTaskResult(
        TaskResult(
          projectName: 'pkg_b',
          targetName: 'build',
          status: TaskStatus.failure,
          exitCode: 1,
          stdout: '',
          stderr: 'Error: something broke',
          duration: Duration(milliseconds: 100),
        ),
      );
      expect(output.toString(), contains('✗'));
      expect(output.toString(), contains('pkg_b:build'));
      expect(output.toString(), contains('something broke'));
    });

    test('writeTaskResult shows cached icon', () {
      tui.writeTaskResult(
        TaskResult(
          projectName: 'pkg_c',
          targetName: 'test',
          status: TaskStatus.cached,
          exitCode: 0,
          stdout: '',
          stderr: '',
          duration: Duration(milliseconds: 5),
        ),
      );
      expect(output.toString(), contains('●'));
    });

    test('writeTaskResult shows skipped icon', () {
      tui.writeTaskResult(
        TaskResult(
          projectName: 'pkg_d',
          targetName: 'test',
          status: TaskStatus.skipped,
          exitCode: -1,
          stdout: '',
          stderr: '',
          duration: Duration.zero,
        ),
      );
      expect(output.toString(), contains('○'));
    });

    test('writeSummary shows counts', () {
      final results = [
        TaskResult(
          projectName: 'a',
          targetName: 'test',
          status: TaskStatus.success,
          exitCode: 0,
          stdout: '',
          stderr: '',
          duration: Duration.zero,
        ),
        TaskResult(
          projectName: 'b',
          targetName: 'test',
          status: TaskStatus.failure,
          exitCode: 1,
          stdout: '',
          stderr: '',
          duration: Duration.zero,
        ),
        TaskResult(
          projectName: 'c',
          targetName: 'test',
          status: TaskStatus.skipped,
          exitCode: -1,
          stdout: '',
          stderr: '',
          duration: Duration.zero,
        ),
      ];
      tui.writeSummary(results, 'test');
      final text = output.toString();
      expect(text, contains('1 passed'));
      expect(text, contains('1 failed'));
      expect(text, contains('1 skipped'));
    });
  });
}
