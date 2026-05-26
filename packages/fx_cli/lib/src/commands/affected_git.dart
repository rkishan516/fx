import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;

/// Shared git/path helpers for affected project selection.
class AffectedGit {
  final ProcessRunner processRunner;

  const AffectedGit({required this.processRunner});

  static List<String> filesFromArg(String workspaceRoot, String filesArg) {
    return filesArg
        .split(',')
        .map((file) => resolveChangedFilePath(workspaceRoot, file))
        .where((file) => file.isNotEmpty)
        .toList();
  }

  static String resolveChangedFilePath(String workspaceRoot, String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) return '';
    if (p.isAbsolute(trimmed)) return p.normalize(trimmed);
    return p.normalize(p.join(workspaceRoot, trimmed));
  }

  static String resolveBase({
    required FxConfig config,
    String? explicitBase,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final base = _nonEmpty(explicitBase);
    if (base != null) return base;

    final defaultBranch = _nonEmpty(env['CI_DEFAULT_BRANCH']);
    final commitBranch = _nonEmpty(env['CI_COMMIT_BRANCH']);
    if (defaultBranch != null && commitBranch == defaultBranch) {
      return _nonZeroSha(env['CI_COMMIT_BEFORE_SHA']) ?? 'HEAD~1';
    }

    if (env['CI_PIPELINE_SOURCE'] == 'merge_request_event') {
      final target = _nonEmpty(env['CI_MERGE_REQUEST_TARGET_BRANCH_NAME']);
      if (target != null) return target;
    }

    return defaultBranch ?? config.defaultBase;
  }

  static bool shouldFetchBase({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    return env.containsKey('GITLAB_CI') ||
        env.containsKey('CI_PIPELINE_SOURCE') ||
        env.containsKey('CI_DEFAULT_BRANCH');
  }

  Future<List<String>> changedFiles({
    required String workspaceRoot,
    required String base,
    required String head,
    bool includeUncommitted = false,
    bool includeUntracked = false,
    bool fetchBase = false,
  }) async {
    final changedLines = <String>[];
    final resolvedBase = fetchBase
        ? await _fetchAndResolveBase(workspaceRoot, base)
        : base;

    final diffResult = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['diff', '--name-only', '$resolvedBase...$head'],
        workingDirectory: workspaceRoot,
      ),
    );
    changedLines.addAll(_pathsFromGitOutput(workspaceRoot, diffResult.stdout));

    if (includeUncommitted) {
      final uncommittedResult = await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: ['diff', '--name-only', 'HEAD'],
          workingDirectory: workspaceRoot,
        ),
      );
      changedLines.addAll(
        _pathsFromGitOutput(workspaceRoot, uncommittedResult.stdout),
      );
    }

    if (includeUntracked) {
      final untrackedResult = await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: ['ls-files', '--others', '--exclude-standard'],
          workingDirectory: workspaceRoot,
        ),
      );
      changedLines.addAll(
        _pathsFromGitOutput(workspaceRoot, untrackedResult.stdout),
      );
    }

    return changedLines.toSet().toList();
  }

  Future<String> _fetchAndResolveBase(String workspaceRoot, String base) async {
    if (_isFullSha(base)) return base;

    final branch = base.startsWith('origin/')
        ? base.substring('origin/'.length)
        : base;
    if (branch.startsWith('refs/') || branch.contains('..')) return base;

    final fetch = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['fetch', 'origin', branch, '--depth=1'],
        workingDirectory: workspaceRoot,
      ),
    );
    if (fetch.exitCode != 0) return base;

    final parse = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['rev-parse', 'FETCH_HEAD'],
        workingDirectory: workspaceRoot,
      ),
    );
    if (parse.exitCode != 0) return base;

    final sha = (parse.stdout as String).trim();
    return sha.isEmpty ? base : sha;
  }

  static List<String> _pathsFromGitOutput(String workspaceRoot, Object stdout) {
    return stdout
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => resolveChangedFilePath(workspaceRoot, line))
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static bool _isFullSha(String value) {
    return RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(value);
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _nonZeroSha(String? value) {
    final sha = _nonEmpty(value);
    if (sha == null || sha == '0' * 40) return null;
    return sha;
  }
}
