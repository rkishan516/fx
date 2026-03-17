import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';

import '../output/output_formatter.dart';

/// `fx ci-info` — Outputs detected CI provider information as structured JSON.
///
/// Useful for CI pipeline configuration scripts that need to know:
/// - Which CI provider is running
/// - The recommended base ref for affected-project detection
/// - Cache paths to warm/restore
/// - Recommended concurrency
class CiInfoCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'ci-info';

  @override
  String get description => 'Output detected CI provider information as JSON.';

  CiInfoCommand({required this.formatter}) {
    argParser.addOption(
      'provider',
      help:
          'Override CI provider detection '
          '(github, gitlab, circleci, travis, jenkins, buildkite, codebuild, azure, bitbucket).',
    );
  }

  @override
  Future<void> run() async {
    final providerOverride = argResults!['provider'] as String?;

    final detectedProvider =
        providerOverride ?? _normalizeProvider(Environment.ciProvider);

    final baseRef = _baseRefForProvider(providerOverride);
    final cachePaths = _cachePathsForProvider(providerOverride);

    final output = const JsonEncoder.withIndent('  ').convert({
      'provider': detectedProvider,
      'baseRef': baseRef,
      'cachePaths': cachePaths,
      'concurrency': Environment.defaultConcurrency,
      'isCI': Environment.isCI || providerOverride != null,
    });

    formatter.writeln(output);
  }

  String? _normalizeProvider(String? provider) {
    if (provider == null) return null;
    return switch (provider) {
      'GitHub Actions' => 'github',
      'GitLab CI' => 'gitlab',
      'CircleCI' => 'circleci',
      'Travis CI' => 'travis',
      'Jenkins' => 'jenkins',
      'Buildkite' => 'buildkite',
      'AWS CodeBuild' => 'codebuild',
      'Azure Pipelines' => 'azure',
      'Bitbucket Pipelines' => 'bitbucket',
      _ => provider.toLowerCase(),
    };
  }

  String _baseRefForProvider(String? providerOverride) {
    if (providerOverride != null) {
      // Map provider name to its typical base-ref env var
      final baseVarByProvider = <String, String>{
        'github': 'GITHUB_BASE_REF',
        'gitlab': 'CI_MERGE_REQUEST_TARGET_BRANCH_NAME',
        'circleci': 'CIRCLE_BASE_REVISION',
        'travis': 'TRAVIS_BRANCH',
        'jenkins': 'GIT_PREVIOUS_SUCCESSFUL_COMMIT',
        'buildkite': 'BUILDKITE_PULL_REQUEST_BASE_BRANCH',
        'codebuild': 'CODEBUILD_WEBHOOK_BASE_REF',
        'azure': 'SYSTEM_PULLREQUEST_TARGETBRANCHNAME',
        'bitbucket': 'BITBUCKET_PR_DESTINATION_BRANCH',
      };
      final envVar = baseVarByProvider[providerOverride.toLowerCase()];
      if (envVar != null) {
        final val = Platform.environment[envVar];
        if (val != null && val.isNotEmpty) return val;
      }
      return 'main';
    }
    return Environment.affectedBase();
  }

  List<String> _cachePathsForProvider(String? providerOverride) {
    final provider =
        providerOverride ?? _normalizeProvider(Environment.ciProvider);
    return switch (provider) {
      'github' => ['.dart_tool', '.pub-cache', '.fx_cache'],
      'gitlab' => ['.dart_tool', '.pub-cache', '.fx_cache'],
      'circleci' => ['~/.pub-cache', '.fx_cache'],
      _ => ['.fx_cache'],
    };
  }
}
