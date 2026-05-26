import 'package:fx_cli/src/commands/affected_git.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('AffectedGit', () {
    const config = FxConfig(
      packages: ['packages/*'],
      targets: {},
      cacheConfig: CacheConfig(enabled: false, directory: '.fx_cache'),
      generators: [],
      defaultBase: 'main',
    );

    test('explicit base wins over CI environment', () {
      final base = AffectedGit.resolveBase(
        config: config,
        explicitBase: 'release',
        environment: {
          'CI_PIPELINE_SOURCE': 'merge_request_event',
          'CI_MERGE_REQUEST_TARGET_BRANCH_NAME': 'master',
        },
      );

      expect(base, 'release');
    });

    test('merge request pipelines use target branch as base', () {
      final base = AffectedGit.resolveBase(
        config: config,
        environment: {
          'CI_PIPELINE_SOURCE': 'merge_request_event',
          'CI_MERGE_REQUEST_TARGET_BRANCH_NAME': 'master',
          'CI_DEFAULT_BRANCH': 'master',
        },
      );

      expect(base, 'master');
    });

    test('default branch pipelines use CI_COMMIT_BEFORE_SHA', () {
      final base = AffectedGit.resolveBase(
        config: config,
        environment: {
          'CI_COMMIT_BRANCH': 'master',
          'CI_DEFAULT_BRANCH': 'master',
          'CI_COMMIT_BEFORE_SHA': 'a' * 40,
        },
      );

      expect(base, 'a' * 40);
    });

    test('all-zero before sha falls back to previous commit', () {
      final base = AffectedGit.resolveBase(
        config: config,
        environment: {
          'CI_COMMIT_BRANCH': 'master',
          'CI_DEFAULT_BRANCH': 'master',
          'CI_COMMIT_BEFORE_SHA': '0' * 40,
        },
      );

      expect(base, 'HEAD~1');
    });

    test('fetches branch base before diffing in CI mode', () async {
      final calls = <ProcessCall>[];
      final runner = MockProcessRunner(
        onRun: (call) {
          calls.add(call);
          if (call.arguments.contains('fetch')) {
            return ProcessResult(exitCode: 0, stdout: '', stderr: '');
          }
          if (call.arguments.contains('rev-parse')) {
            return ProcessResult(exitCode: 0, stdout: 'b' * 40, stderr: '');
          }
          if (call.arguments.contains('diff')) {
            return ProcessResult(
              exitCode: 0,
              stdout: 'packages/pkg_b/lib/pkg_b.dart',
              stderr: '',
            );
          }
          return ProcessResult(exitCode: 0, stdout: '', stderr: '');
        },
      );

      final files = await AffectedGit(processRunner: runner).changedFiles(
        workspaceRoot: '/ws',
        base: 'master',
        head: 'HEAD',
        fetchBase: true,
      );

      expect(files, equals(['/ws/packages/pkg_b/lib/pkg_b.dart']));
      expect(
        calls[0].arguments,
        equals(['fetch', 'origin', 'master', '--depth=1']),
      );
      expect(calls[1].arguments, equals(['rev-parse', 'FETCH_HEAD']));
      expect(
        calls[2].arguments,
        equals(['diff', '--name-only', '${'b' * 40}...HEAD']),
      );
    });
  });
}
