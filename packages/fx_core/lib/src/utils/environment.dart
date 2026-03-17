import 'dart:io';

/// Detects the runtime environment (CI, local, etc.) and provides
/// environment-aware configuration.
class Environment {
  /// Whether we are running in a CI environment.
  static bool get isCI {
    // FX_CI env var override
    if (Platform.environment.containsKey('FX_CI')) return true;

    // Common CI environment variables
    const ciVars = [
      'CI',
      'CONTINUOUS_INTEGRATION',
      'GITHUB_ACTIONS',
      'GITLAB_CI',
      'CIRCLECI',
      'TRAVIS',
      'JENKINS_URL',
      'BUILDKITE',
      'CODEBUILD_BUILD_ID',
      'TF_BUILD', // Azure Pipelines
      'BITBUCKET_BUILD_NUMBER',
    ];

    return ciVars.any((v) => Platform.environment.containsKey(v));
  }

  /// The detected CI provider name, or null if not in CI.
  static String? get ciProvider {
    if (Platform.environment.containsKey('GITHUB_ACTIONS')) {
      return 'GitHub Actions';
    }
    if (Platform.environment.containsKey('GITLAB_CI')) return 'GitLab CI';
    if (Platform.environment.containsKey('CIRCLECI')) return 'CircleCI';
    if (Platform.environment.containsKey('TRAVIS')) return 'Travis CI';
    if (Platform.environment.containsKey('JENKINS_URL')) return 'Jenkins';
    if (Platform.environment.containsKey('BUILDKITE')) return 'Buildkite';
    if (Platform.environment.containsKey('CODEBUILD_BUILD_ID')) {
      return 'AWS CodeBuild';
    }
    if (Platform.environment.containsKey('TF_BUILD')) return 'Azure Pipelines';
    if (Platform.environment.containsKey('BITBUCKET_BUILD_NUMBER')) {
      return 'Bitbucket Pipelines';
    }
    if (Platform.environment.containsKey('CI')) return 'Unknown CI';
    return null;
  }

  /// Whether ANSI color output should be used.
  static bool get useColor {
    if (isCI) return false;
    if (Platform.environment.containsKey('NO_COLOR')) return false;
    if (Platform.environment['TERM'] == 'dumb') return false;
    return stdout.hasTerminal;
  }

  /// Whether interactive prompts are allowed.
  static bool get isInteractive {
    if (isCI) return false;
    return stdin.hasTerminal;
  }

  /// The number of parallel workers to use.
  static int get defaultConcurrency {
    final envValue = Platform.environment['FX_CONCURRENCY'];
    if (envValue != null) {
      final parsed = int.tryParse(envValue);
      if (parsed != null && parsed > 0) return parsed;
    }
    return Platform.numberOfProcessors;
  }

  // ---------------------------------------------------------------------------
  // Affected base detection
  // ---------------------------------------------------------------------------

  /// Maps CI provider detection env var → provider-specific base-ref env var.
  static const _providerBaseVars = <String, String>{
    'GITHUB_ACTIONS': 'GITHUB_BASE_REF',
    'GITLAB_CI': 'CI_MERGE_REQUEST_TARGET_BRANCH_NAME',
    'CIRCLECI': 'CIRCLE_BASE_REVISION',
    'TRAVIS': 'TRAVIS_BRANCH',
    'JENKINS_URL': 'GIT_PREVIOUS_SUCCESSFUL_COMMIT',
    'BUILDKITE': 'BUILDKITE_PULL_REQUEST_BASE_BRANCH',
    'CODEBUILD_BUILD_ID': 'CODEBUILD_WEBHOOK_BASE_REF',
    'TF_BUILD': 'SYSTEM_PULLREQUEST_TARGETBRANCHNAME',
    'BITBUCKET_BUILD_NUMBER': 'BITBUCKET_PR_DESTINATION_BRANCH',
  };

  /// Returns the recommended git base ref for computing affected projects.
  ///
  /// Checks the current CI provider and returns the provider-specific base ref
  /// env var value. Falls back to [defaultBase] when no suitable var is set.
  static String affectedBase({String defaultBase = 'main'}) =>
      affectedBaseFromEnv(Platform.environment, defaultBase: defaultBase);

  /// Testable version of [affectedBase] that accepts an explicit [env] map.
  static String affectedBaseFromEnv(
    Map<String, String> env, {
    String defaultBase = 'main',
  }) {
    for (final entry in _providerBaseVars.entries) {
      if (env.containsKey(entry.key)) {
        final baseRef = env[entry.value];
        if (baseRef != null && baseRef.isNotEmpty) return baseRef;
        break;
      }
    }
    return defaultBase;
  }

  // ---------------------------------------------------------------------------
  // CI log grouping
  // ---------------------------------------------------------------------------

  /// Start a log group named [name].
  ///
  /// Output format depends on the CI provider detected from
  /// [Platform.environment].
  static void groupStart(String name, StringSink sink) =>
      groupStartToSink(name, sink, env: Platform.environment);

  /// End the current log group.
  static void groupEnd(StringSink sink) =>
      groupEndToSink(sink, env: Platform.environment);

  /// Testable version of [groupStart] with explicit [env].
  static void groupStartToSink(
    String name,
    StringSink sink, {
    required Map<String, String> env,
  }) {
    if (env.containsKey('GITHUB_ACTIONS')) {
      sink.writeln('::group::$name');
    } else if (env.containsKey('GITLAB_CI')) {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final key = name.replaceAll(' ', '_').toLowerCase();
      sink.writeln('\x1b[0Ksection_start:$ts:$key\r\x1b[0K$name');
    } else {
      sink.writeln('--- $name ---');
    }
  }

  /// Testable version of [groupEnd] with explicit [env].
  static void groupEndToSink(
    StringSink sink, {
    required Map<String, String> env,
  }) {
    if (env.containsKey('GITHUB_ACTIONS')) {
      sink.writeln('::endgroup::');
    } else if (env.containsKey('GITLAB_CI')) {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      sink.writeln('\x1b[0Ksection_end:$ts:section\r\x1b[0K');
    }
    // For other providers/local: no closing marker needed
  }

  /// Summary of the detected environment.
  static Map<String, dynamic> toJson() => {
    'isCI': isCI,
    'ciProvider': ciProvider,
    'useColor': useColor,
    'isInteractive': isInteractive,
    'concurrency': defaultConcurrency,
    'platform': Platform.operatingSystem,
    'dartVersion': Platform.version.split(' ').first,
  };
}
