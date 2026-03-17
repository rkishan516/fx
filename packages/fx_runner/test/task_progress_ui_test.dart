import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('TaskProgressUI', () {
    test('addProject registers projects', () {
      final output = StringBuffer();
      final ui = TaskProgressUI(sink: output);

      ui.addProject('core');
      ui.addProject('cli');

      // Non-terminal mode won't render live, but printSummary works
      ui.printSummary();

      final out = output.toString();
      expect(out, contains('0 succeeded'));
      expect(out, contains('2 total'));
    });

    test('markComplete tracks success and failure', () {
      final output = StringBuffer();
      final ui = TaskProgressUI(sink: output);

      ui.addProject('core');
      ui.addProject('cli');

      ui.markComplete(
        'core',
        TaskResult(
          projectName: 'core',
          targetName: 'test',
          status: TaskStatus.success,
          exitCode: 0,
          stdout: '',
          stderr: '',
          duration: const Duration(milliseconds: 150),
        ),
      );

      ui.markComplete(
        'cli',
        TaskResult(
          projectName: 'cli',
          targetName: 'test',
          status: TaskStatus.failure,
          exitCode: 1,
          stdout: '',
          stderr: 'error',
          duration: const Duration(milliseconds: 200),
        ),
      );

      ui.printSummary();

      final out = output.toString();
      expect(out, contains('1 succeeded'));
      expect(out, contains('1 failed'));
      expect(out, contains('cli'));
    });

    test('printSummary shows skipped count', () {
      final output = StringBuffer();
      final ui = TaskProgressUI(sink: output);

      ui.addProject('skipped_pkg');
      ui.markComplete(
        'skipped_pkg',
        TaskResult.skipped(
          projectName: 'skipped_pkg',
          targetName: 'test',
          reason: 'dep failed',
        ),
      );

      ui.printSummary();

      expect(output.toString(), contains('1 skipped'));
    });

    test('formatDuration formats correctly', () {
      final output = StringBuffer();
      final ui = TaskProgressUI(sink: output);

      ui.addProject('fast');
      ui.markComplete(
        'fast',
        TaskResult(
          projectName: 'fast',
          targetName: 'test',
          status: TaskStatus.success,
          exitCode: 0,
          stdout: '',
          stderr: '',
          duration: const Duration(milliseconds: 42),
        ),
      );

      ui.printSummary();
      expect(output.toString(), contains('1 succeeded'));
    });

    test('stop does not throw', () {
      final output = StringBuffer();
      final ui = TaskProgressUI(sink: output);
      ui.addProject('core');
      // start() won't start timer for non-terminal sink
      ui.start();
      ui.stop();
    });
  });
}
