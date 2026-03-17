import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;

import '../output/output_formatter.dart';
import 'run_command.dart';

/// Version bumping logic for release commands.
class VersionBumper {
  final ProcessRunner processRunner;
  final OutputFormatter formatter;

  const VersionBumper({required this.processRunner, required this.formatter});

  /// Bump versions for the given projects, optionally updating dependents.
  ///
  /// [updateDependents] controls how dependent packages are updated:
  /// - `always`: patch-bump dependents and update their constraints
  /// - `auto`: update constraint only if the new version would break it
  /// - `never`: don't touch dependent packages
  Future<void> bumpVersions(
    List<Project> projects,
    String bumpType,
    bool dryRun, {
    String updateDependents = 'never',
    List<Project> allProjects = const [],
  }) async {
    // Track version changes: projectName -> newVersion
    final versionChanges = <String, String>{};

    for (final project in projects) {
      final pubspecPath = p.join(project.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;

      final content = pubspecFile.readAsStringSync();
      final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
      if (versionMatch == null) continue;

      final currentVersion = versionMatch.group(1)!.trim();
      final newVersion = bumpVersion(currentVersion, bumpType);
      versionChanges[project.name] = newVersion;

      if (dryRun) {
        formatter.writeln(
          '${project.name}: $currentVersion -> $newVersion (dry-run)',
        );
      } else {
        final updated = content.replaceFirst(
          'version: $currentVersion',
          'version: $newVersion',
        );
        pubspecFile.writeAsStringSync(updated);
        formatter.writeln('${project.name}: $currentVersion -> $newVersion');
      }
    }

    // Update dependents if configured
    if (updateDependents != 'never' && versionChanges.isNotEmpty) {
      await _updateDependentConstraints(
        versionChanges: versionChanges,
        allProjects: allProjects.isNotEmpty ? allProjects : projects,
        mode: updateDependents,
        dryRun: dryRun,
      );
    }
  }

  /// Update dependency constraints in packages that depend on bumped packages.
  Future<void> _updateDependentConstraints({
    required Map<String, String> versionChanges,
    required List<Project> allProjects,
    required String mode,
    required bool dryRun,
  }) async {
    final bumpedNames = versionChanges.keys.toSet();

    for (final project in allProjects) {
      if (bumpedNames.contains(project.name)) continue;

      final pubspecPath = p.join(project.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;

      var content = pubspecFile.readAsStringSync();
      var modified = false;

      for (final entry in versionChanges.entries) {
        final depName = entry.key;
        final newVersion = entry.value;

        if (!project.dependencies.contains(depName)) continue;

        // Find the dependency constraint in pubspec.yaml
        final depPattern = RegExp(
          '(\\s+${RegExp.escape(depName)}:\\s*)(\\^?[0-9][^\\s]*)',
        );
        final match = depPattern.firstMatch(content);
        if (match == null) continue;

        final currentConstraint = match.group(2)!;
        final shouldUpdate =
            mode == 'always' ||
            (mode == 'auto' &&
                !_constraintSatisfies(currentConstraint, newVersion));

        if (shouldUpdate) {
          final newConstraint = '^$newVersion';
          content = content.replaceFirst(
            '${match.group(1)}$currentConstraint',
            '${match.group(1)}$newConstraint',
          );
          modified = true;
          if (dryRun) {
            formatter.writeln(
              '  ${project.name}: $depName constraint $currentConstraint -> $newConstraint (dry-run)',
            );
          } else {
            formatter.writeln(
              '  ${project.name}: $depName constraint $currentConstraint -> $newConstraint',
            );
          }
        }
      }

      if (modified && !dryRun) {
        pubspecFile.writeAsStringSync(content);
      }
    }
  }

  /// Check if a caret constraint (e.g., `^1.2.0`) satisfies the given version.
  bool _constraintSatisfies(String constraint, String version) {
    // Simple caret range check: ^X.Y.Z allows X.Y.Z <= v < (X+1).0.0
    final cleanConstraint = constraint.startsWith('^')
        ? constraint.substring(1)
        : constraint;
    final cParts = cleanConstraint.split('-').first.split('.');
    final vParts = version.split('-').first.split('.');

    if (cParts.length < 3 || vParts.length < 3) return false;

    final cMajor = int.tryParse(cParts[0]) ?? 0;
    final vMajor = int.tryParse(vParts[0]) ?? 0;

    // Caret: same major version required
    if (!constraint.startsWith('^')) return cleanConstraint == version;
    return cMajor == vMajor;
  }

  /// Compute bumped version string from current version and bump type.
  String bumpVersion(
    String current,
    String bumpType, {
    String preid = 'alpha',
  }) {
    if (bumpType.contains('.') && !bumpType.startsWith('pre')) return bumpType;

    final baseCurrent = current.split('-').first;
    final parts = baseCurrent.split('.');
    if (parts.length < 3) return current;

    var major = int.tryParse(parts[0]) ?? 0;
    var minor = int.tryParse(parts[1]) ?? 0;
    var patch = int.tryParse(parts[2]) ?? 0;

    switch (bumpType) {
      case 'major':
        major++;
        minor = 0;
        patch = 0;
      case 'minor':
        minor++;
        patch = 0;
      case 'patch':
        patch++;
      case 'premajor':
        major++;
        minor = 0;
        patch = 0;
        return '$major.$minor.$patch-$preid.0';
      case 'preminor':
        minor++;
        patch = 0;
        return '$major.$minor.$patch-$preid.0';
      case 'prepatch':
        patch++;
        return '$major.$minor.$patch-$preid.0';
      case 'prerelease':
        if (current.contains('-')) {
          final preMatch = RegExp(r'-(.+)\.(\d+)$').firstMatch(current);
          if (preMatch != null) {
            final preNum = int.parse(preMatch.group(2)!);
            return '$major.$minor.$patch-${preMatch.group(1)}.${preNum + 1}';
          }
        }
        patch++;
        return '$major.$minor.$patch-$preid.0';
    }

    return '$major.$minor.$patch';
  }

  /// Auto-determine version bump from conventional commits since last tag.
  Future<String> autoBumpFromCommits(Workspace workspace) async {
    final tagResult = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['describe', '--tags', '--abbrev=0'],
        workingDirectory: workspace.rootPath,
      ),
    );

    final logArgs = ['log', '--oneline', '--no-decorate'];
    if (tagResult.exitCode == 0 && tagResult.stdout.trim().isNotEmpty) {
      logArgs.add('${tagResult.stdout.trim()}..HEAD');
    } else {
      logArgs.addAll(['-100', 'HEAD']);
    }

    final logResult = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: logArgs,
        workingDirectory: workspace.rootPath,
      ),
    );

    final commits = logResult.stdout
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    var bump = 'patch';
    for (final commit in commits) {
      if (commit.contains('!:') || commit.contains('BREAKING CHANGE')) {
        bump = 'major';
        break;
      }
      if (RegExp(r'\bfeat(\([^)]*\))?\s*:').hasMatch(commit)) {
        bump = 'minor';
      }
    }

    formatter.writeln('Auto-detected version bump: $bump');
    return bump;
  }
}

/// Changelog generation from git log.
class ChangelogGenerator {
  final ProcessRunner processRunner;
  final OutputFormatter formatter;

  const ChangelogGenerator({
    required this.processRunner,
    required this.formatter,
  });

  /// Generate changelog from git commits and optionally write to files.
  Future<void> generate(
    Workspace workspace,
    List<Project> projects,
    bool dryRun, {
    bool firstRelease = false,
    String? fromRef,
    String toRef = 'HEAD',
  }) async {
    final logArgs = ['log', '--oneline', '--no-decorate'];
    if (fromRef != null) {
      logArgs.add('$fromRef..$toRef');
    } else if (firstRelease) {
      logArgs.add(toRef);
    } else {
      final tagResult = await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: ['describe', '--tags', '--abbrev=0'],
          workingDirectory: workspace.rootPath,
        ),
      );
      if (tagResult.exitCode == 0 && tagResult.stdout.trim().isNotEmpty) {
        logArgs.add('${tagResult.stdout.trim()}..$toRef');
      } else {
        logArgs.addAll(['-50', toRef]);
      }
    }

    final result = await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: logArgs,
        workingDirectory: workspace.rootPath,
      ),
    );

    final commits = result.stdout
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final content = _formatChangelog(commits);

    if (dryRun) {
      formatter.writeln('Generated changelog (dry-run):');
      formatter.writeln(content);
    } else {
      _writeChangelog(p.join(workspace.rootPath, 'CHANGELOG.md'), content);
      formatter.writeln('Updated CHANGELOG.md');

      if (projects.length > 1) {
        for (final project in projects) {
          _writeChangelog(p.join(project.path, 'CHANGELOG.md'), content);
        }
        formatter.writeln(
          'Updated CHANGELOG.md for ${projects.length} projects',
        );
      }
    }
  }

  String _formatChangelog(List<String> commits) {
    final conventionalPattern = RegExp(
      r'^[a-f0-9]+\s+(feat|fix|refactor|perf|docs|test|chore|ci|build|style|revert)(\(([^)]+)\))?(!)?\s*:\s*(.+)$',
    );

    final features = <String>[];
    final fixes = <String>[];
    final performance = <String>[];
    final breaking = <String>[];
    final other = <String>[];

    for (final commit in commits) {
      final match = conventionalPattern.firstMatch(commit);
      if (match != null) {
        final type = match.group(1)!;
        final scope = match.group(3);
        final isBreaking = match.group(4) == '!';
        final message = match.group(5)!.trim();

        final formatted = scope != null ? '**$scope:** $message' : message;

        if (isBreaking) {
          breaking.add(formatted);
        } else {
          switch (type) {
            case 'feat':
              features.add(formatted);
            case 'fix':
              fixes.add(formatted);
            case 'perf':
              performance.add(formatted);
            default:
              other.add(formatted);
          }
        }
      } else {
        final msg = commit.replaceFirst(RegExp(r'^[a-f0-9]+\s+'), '');
        other.add(msg);
      }
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer();
    buf.writeln('## [$dateStr]');
    buf.writeln('');
    if (breaking.isNotEmpty) {
      buf.writeln('### BREAKING CHANGES');
      for (final b in breaking) {
        buf.writeln('- $b');
      }
      buf.writeln('');
    }
    if (features.isNotEmpty) {
      buf.writeln('### Features');
      for (final f in features) {
        buf.writeln('- $f');
      }
      buf.writeln('');
    }
    if (fixes.isNotEmpty) {
      buf.writeln('### Bug Fixes');
      for (final f in fixes) {
        buf.writeln('- $f');
      }
      buf.writeln('');
    }
    if (performance.isNotEmpty) {
      buf.writeln('### Performance');
      for (final p in performance) {
        buf.writeln('- $p');
      }
      buf.writeln('');
    }
    if (other.isNotEmpty) {
      buf.writeln('### Other');
      for (final o in other) {
        buf.writeln('- $o');
      }
    }
    return buf.toString();
  }

  void _writeChangelog(String path, String newContent) {
    final file = File(path);
    final existing = file.existsSync() ? file.readAsStringSync() : '';
    file.writeAsStringSync('$newContent\n$existing');
  }
}

/// Git operations for releases (commit, tag, push, GitHub release).
class ReleaseGitOps {
  final ProcessRunner processRunner;
  final OutputFormatter formatter;

  const ReleaseGitOps({required this.processRunner, required this.formatter});

  Future<void> commit(Workspace workspace, String message) async {
    // Stage only version/changelog files, not all workspace files
    await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['add', '**/pubspec.yaml', '**/CHANGELOG.md'],
        workingDirectory: workspace.rootPath,
      ),
    );
    await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['commit', '-m', message],
        workingDirectory: workspace.rootPath,
      ),
    );
    formatter.writeln('Created git commit: $message');
  }

  Future<void> tag(Workspace workspace, List<Project> projects) async {
    final releaseConfig = workspace.config.releaseConfig;
    final relationship = releaseConfig?.projectsRelationship ?? 'fixed';
    final tagPattern = releaseConfig?.releaseTagPattern;

    for (final project in projects) {
      final pubspecPath = p.join(project.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;
      final content = pubspecFile.readAsStringSync();
      final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
      if (versionMatch == null) continue;
      final version = versionMatch.group(1)!.trim();

      final tagName = resolveTag(
        project.name,
        version,
        tagPattern: tagPattern,
        relationship: relationship,
      );

      await processRunner.run(
        ProcessCall(
          executable: 'git',
          arguments: ['tag', tagName],
          workingDirectory: workspace.rootPath,
        ),
      );
      formatter.writeln('Created tag: $tagName');
    }
  }

  Future<void> push(Workspace workspace) async {
    await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['push'],
        workingDirectory: workspace.rootPath,
      ),
    );
    await processRunner.run(
      ProcessCall(
        executable: 'git',
        arguments: ['push', '--tags'],
        workingDirectory: workspace.rootPath,
      ),
    );
    formatter.writeln('Pushed commits and tags to remote.');
  }

  Future<void> createGitHubRelease(
    Workspace workspace,
    List<Project> projects,
  ) async {
    final releaseConfig = workspace.config.releaseConfig;
    final relationship = releaseConfig?.projectsRelationship ?? 'fixed';

    for (final project in projects) {
      final pubspecPath = p.join(project.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;
      final content = pubspecFile.readAsStringSync();
      final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
      if (versionMatch == null) continue;
      final version = versionMatch.group(1)!.trim();

      final tagPattern = releaseConfig?.releaseTagPattern;
      final tagName = resolveTag(
        project.name,
        version,
        tagPattern: tagPattern,
        relationship: relationship,
      );

      final result = await processRunner.run(
        ProcessCall(
          executable: 'gh',
          arguments: [
            'release',
            'create',
            tagName,
            '--title',
            tagName,
            '--generate-notes',
          ],
          workingDirectory: workspace.rootPath,
        ),
      );

      if (result.exitCode == 0) {
        formatter.writeln('Created GitHub Release: $tagName');
      } else {
        formatter.writeln(
          'Warning: Failed to create GitHub Release for $tagName: ${result.stderr}',
        );
      }

      if (relationship == 'fixed') break;
    }
  }

  /// Resolve tag name from project name, version, and config.
  String resolveTag(
    String projectName,
    String version, {
    String? tagPattern,
    String relationship = 'fixed',
  }) {
    if (tagPattern != null) {
      return tagPattern
          .replaceAll('{projectName}', projectName)
          .replaceAll('{version}', version);
    } else if (relationship == 'independent') {
      return '$projectName-v$version';
    } else {
      return 'v$version';
    }
  }
}

/// Publishing logic.
class ReleasePublisher {
  final ProcessRunner processRunner;
  final OutputFormatter formatter;

  const ReleasePublisher({
    required this.processRunner,
    required this.formatter,
  });

  Future<void> publish(
    Workspace workspace,
    List<Project> projects,
    bool dryRun,
  ) async {
    final graph = ProjectGraph.build(workspace.projects);
    final sorted = TopologicalSort.sort(projects, graph);

    for (final project in sorted) {
      final pubspecContent = File(
        p.join(project.path, 'pubspec.yaml'),
      ).readAsStringSync();
      if (pubspecContent.contains('publish_to: none')) {
        formatter.writeln('${project.name}: skipped (publish_to: none)');
        continue;
      }

      final args = ['pub', 'publish'];
      if (dryRun) args.add('--dry-run');
      args.add('--force');

      formatter.writeln('Publishing ${project.name}...');
      final result = await processRunner.run(
        ProcessCall(
          executable: 'dart',
          arguments: args,
          workingDirectory: project.path,
        ),
      );

      if (result.exitCode != 0) {
        formatter.writeln('Failed to publish ${project.name}:');
        formatter.writeln(result.stderr);
        throw const ProcessExit(1);
      }
      formatter.writeln('${project.name}: published successfully');
    }
  }
}
