import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('Environment', () {
    test('toJson returns expected keys', () {
      final json = Environment.toJson();
      expect(json, containsPair('isCI', isA<bool>()));
      expect(json, containsPair('useColor', isA<bool>()));
      expect(json, containsPair('isInteractive', isA<bool>()));
      expect(json, containsPair('concurrency', isA<int>()));
      expect(json, containsPair('platform', isA<String>()));
      expect(json, containsPair('dartVersion', isA<String>()));
    });

    test('defaultConcurrency returns positive integer', () {
      expect(Environment.defaultConcurrency, greaterThan(0));
    });

    test('ciProvider returns String or null', () {
      // In test environment, this should be consistent
      final provider = Environment.ciProvider;
      expect(provider, anyOf(isNull, isA<String>()));
    });

    group('affectedBase()', () {
      test('returns GITHUB_BASE_REF for GitHub Actions', () {
        final base = Environment.affectedBaseFromEnv({
          'GITHUB_ACTIONS': 'true',
          'GITHUB_BASE_REF': 'main',
        });
        expect(base, 'main');
      });

      test('returns CI_MERGE_REQUEST_TARGET_BRANCH_NAME for GitLab CI', () {
        final base = Environment.affectedBaseFromEnv({
          'GITLAB_CI': 'true',
          'CI_MERGE_REQUEST_TARGET_BRANCH_NAME': 'develop',
        });
        expect(base, 'develop');
      });

      test('returns CIRCLE_BASE_REVISION for CircleCI', () {
        final base = Environment.affectedBaseFromEnv({
          'CIRCLECI': 'true',
          'CIRCLE_BASE_REVISION': 'abc123',
        });
        expect(base, 'abc123');
      });

      test('returns TRAVIS_BRANCH for Travis CI', () {
        final base = Environment.affectedBaseFromEnv({
          'TRAVIS': 'true',
          'TRAVIS_BRANCH': 'main',
        });
        expect(base, 'main');
      });

      test('returns GIT_PREVIOUS_SUCCESSFUL_COMMIT for Jenkins', () {
        final base = Environment.affectedBaseFromEnv({
          'JENKINS_URL': 'http://jenkins',
          'GIT_PREVIOUS_SUCCESSFUL_COMMIT': 'base_sha',
        });
        expect(base, 'base_sha');
      });

      test('returns BUILDKITE_PULL_REQUEST_BASE_BRANCH for Buildkite', () {
        final base = Environment.affectedBaseFromEnv({
          'BUILDKITE': 'true',
          'BUILDKITE_PULL_REQUEST_BASE_BRANCH': 'release',
        });
        expect(base, 'release');
      });

      test('returns CODEBUILD_WEBHOOK_BASE_REF for AWS CodeBuild', () {
        final base = Environment.affectedBaseFromEnv({
          'CODEBUILD_BUILD_ID': 'build-1',
          'CODEBUILD_WEBHOOK_BASE_REF': 'refs/heads/main',
        });
        expect(base, 'refs/heads/main');
      });

      test(
        'returns SYSTEM_PULLREQUEST_TARGETBRANCHNAME for Azure Pipelines',
        () {
          final base = Environment.affectedBaseFromEnv({
            'TF_BUILD': 'True',
            'SYSTEM_PULLREQUEST_TARGETBRANCHNAME': 'main',
          });
          expect(base, 'main');
        },
      );

      test(
        'returns BITBUCKET_PR_DESTINATION_BRANCH for Bitbucket Pipelines',
        () {
          final base = Environment.affectedBaseFromEnv({
            'BITBUCKET_BUILD_NUMBER': '42',
            'BITBUCKET_PR_DESTINATION_BRANCH': 'main',
          });
          expect(base, 'main');
        },
      );

      test(
        'falls back to defaultBase when no provider-specific var is set',
        () {
          final base = Environment.affectedBaseFromEnv({
            'GITHUB_ACTIONS': 'true',
            // No GITHUB_BASE_REF set
          });
          expect(base, 'main');
        },
      );

      test('falls back to defaultBase in non-CI environment', () {
        final base = Environment.affectedBaseFromEnv({});
        expect(base, 'main');
      });

      test('fallback uses custom defaultBase when provided', () {
        final base = Environment.affectedBaseFromEnv(
          {},
          defaultBase: 'develop',
        );
        expect(base, 'develop');
      });
    });

    group('groupStart / groupEnd', () {
      test('GitHub Actions outputs ::group:: syntax', () {
        final buf = StringBuffer();
        Environment.groupStartToSink(
          'Building',
          buf,
          env: {'GITHUB_ACTIONS': 'true'},
        );
        Environment.groupEndToSink(buf, env: {'GITHUB_ACTIONS': 'true'});
        final out = buf.toString();
        expect(out, contains('::group::Building'));
        expect(out, contains('::endgroup::'));
      });

      test('GitLab CI outputs section syntax', () {
        final buf = StringBuffer();
        Environment.groupStartToSink('Tests', buf, env: {'GITLAB_CI': 'true'});
        Environment.groupEndToSink(buf, env: {'GITLAB_CI': 'true'});
        final out = buf.toString();
        expect(out, contains('section_start'));
        expect(out, contains('section_end'));
      });

      test('non-CI environment outputs plain text header', () {
        final buf = StringBuffer();
        Environment.groupStartToSink('Deploy', buf, env: {});
        Environment.groupEndToSink(buf, env: {});
        final out = buf.toString();
        expect(out, contains('Deploy'));
      });
    });
  });
}
