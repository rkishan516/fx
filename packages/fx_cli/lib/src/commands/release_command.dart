import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;

import '../output/output_formatter.dart';
import 'release_helpers.dart';
import 'run_command.dart';

/// `fx release` — Version, changelog, and publish management.
class ReleaseCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  late final VersionBumper _bumper;
  late final ChangelogGenerator _changelogGen;
  late final ReleaseGitOps _gitOps;
  late final ReleasePublisher _publisher;

  @override
  String get name => 'release';

  @override
  String get description =>
      'Manage package versions, changelogs, and publishing.\n\n'
      'Subcommands:\n'
      '  fx release version [--bump major|minor|patch|<version>]\n'
      '  fx release changelog\n'
      '  fx release publish [--dry-run]';

  ReleaseCommand({required this.formatter, required this.processRunner}) {
    _bumper = VersionBumper(processRunner: processRunner, formatter: formatter);
    _changelogGen = ChangelogGenerator(
      processRunner: processRunner,
      formatter: formatter,
    );
    _gitOps = ReleaseGitOps(processRunner: processRunner, formatter: formatter);
    _publisher = ReleasePublisher(
      processRunner: processRunner,
      formatter: formatter,
    );

    argParser
      ..addOption(
        'bump',
        help:
            'Version bump type: major, minor, patch, premajor, preminor, prepatch, prerelease, or explicit version.',
        defaultsTo: 'patch',
      )
      ..addOption(
        'preid',
        help: 'Prerelease identifier (e.g., alpha, beta, rc).',
      )
      ..addFlag(
        'first-release',
        help:
            'Mark this as the first release (skip changelog from-tag lookup).',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Preview changes without writing files.',
        negatable: false,
      )
      ..addFlag(
        'git-commit',
        help: 'Create a git commit for the release.',
        defaultsTo: true,
      )
      ..addFlag(
        'git-tag',
        help: 'Create git tags for released packages.',
        defaultsTo: true,
      )
      ..addFlag(
        'git-push',
        help: 'Push commits and tags to remote.',
        negatable: false,
      )
      ..addOption(
        'version',
        help: 'Explicit version to set (overrides --bump).',
      )
      ..addFlag(
        'interactive',
        help: 'Choose version interactively for each project.',
        negatable: false,
      )
      ..addFlag(
        'conventional-commits',
        help: 'Auto-determine version bump from conventional commit messages.',
        negatable: false,
      )
      ..addFlag(
        'create-release',
        help: 'Create a GitHub Release using the gh CLI.',
        negatable: false,
      )
      ..addOption(
        'group',
        help: 'Release only projects in the specified release group.',
      )
      ..addOption(
        'projects',
        help: 'Comma-separated list of projects to release.',
      )
      ..addOption(
        'from',
        help: 'Git ref to start changelog from (tag or commit).',
      )
      ..addOption(
        'to',
        help: 'Git ref to end changelog at (default: HEAD).',
        defaultsTo: 'HEAD',
      )
      ..addOption(
        'workspace',
        help: 'Path to workspace root (for testing).',
        hide: true,
      );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    final workspacePath = argResults!['workspace'] as String?;
    final dryRun = argResults!['dry-run'] as bool;
    final bumpType = argResults!['bump'] as String;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    final selected = _selectProjects(workspace);

    final explicitVersion = argResults!['version'] as String?;
    final gitCommit = argResults!['git-commit'] as bool;
    final gitTag = argResults!['git-tag'] as bool;
    final gitPush = argResults!['git-push'] as bool;
    final firstRelease = argResults!['first-release'] as bool;
    final conventionalCommits = argResults!['conventional-commits'] as bool;
    final createRelease = argResults!['create-release'] as bool;

    if (rest.isEmpty) {
      throw UsageException(
        'Usage: fx release version|changelog|publish|plan|plan:check',
        usage,
      );
    }

    switch (rest[0]) {
      case 'version':
        String effectiveBump;
        if (conventionalCommits) {
          effectiveBump = await _bumper.autoBumpFromCommits(workspace);
        } else {
          effectiveBump = explicitVersion ?? bumpType;
        }
        final updateDeps =
            workspace.config.releaseConfig?.updateDependents ?? 'auto';
        await _bumper.bumpVersions(
          selected,
          effectiveBump,
          dryRun,
          updateDependents: updateDeps,
          allProjects: workspace.projects,
        );
        if (!dryRun && gitCommit) {
          await _gitOps.commit(workspace, 'chore(release): version bump');
        }
        if (!dryRun && gitTag) {
          await _gitOps.tag(workspace, selected);
        }
        if (!dryRun && gitPush) {
          await _gitOps.push(workspace);
        }
        if (!dryRun && createRelease) {
          await _gitOps.createGitHubRelease(workspace, selected);
        }
      case 'changelog':
        await _changelogGen.generate(
          workspace,
          selected,
          dryRun,
          firstRelease: firstRelease,
          fromRef: argResults!['from'] as String?,
          toRef: argResults!['to'] as String,
        );
      case 'publish':
        await _publisher.publish(workspace, selected, dryRun);
      case 'plan':
        await _releasePlan(workspace, selected);
      case 'plan:check':
        await _releasePlanCheck(workspace, selected);
      default:
        throw UsageException('Unknown subcommand: ${rest[0]}', usage);
    }
  }

  List<Project> _selectProjects(Workspace workspace) {
    var projects = workspace.projects;

    // Filter by --projects
    final projectsArg = argResults!['projects'] as String?;
    if (projectsArg != null && projectsArg.isNotEmpty) {
      final names = projectsArg.split(',').map((s) => s.trim()).toSet();
      projects = projects.where((p) => names.contains(p.name)).toList();
    }

    // Filter by --group (release group)
    final groupArg = argResults!['group'] as String?;
    if (groupArg != null && workspace.config.releaseConfig != null) {
      final group = workspace.config.releaseConfig!.groups[groupArg];
      if (group != null && group.projects.isNotEmpty) {
        final groupNames = group.projects.toSet();
        projects = projects.where((p) => groupNames.contains(p.name)).toList();
      }
    }

    return projects;
  }

  Future<void> _releasePlan(Workspace workspace, List<Project> projects) async {
    final graph = ProjectGraph.build(workspace.projects);
    final sorted = TopologicalSort.sort(projects, graph);

    formatter.writeln('Release Plan:');
    formatter.writeln('');
    var step = 1;
    for (final project in sorted) {
      final pubspecPath = p.join(project.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;
      final content = pubspecFile.readAsStringSync();
      if (content.contains('publish_to: none')) continue;

      final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
      final version = versionMatch?.group(1)?.trim() ?? 'unknown';
      formatter.writeln(
        '  $step. ${project.name} (v$version) → depends on: ${project.dependencies.isEmpty ? 'none' : project.dependencies.join(', ')}',
      );
      step++;
    }
    formatter.writeln('');
    formatter.writeln(
      '${step - 1} package(s) will be published in this order.',
    );
  }

  Future<void> _releasePlanCheck(
    Workspace workspace,
    List<Project> projects,
  ) async {
    var issues = 0;

    for (final project in projects) {
      final pubspecPath = p.join(project.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) continue;
      final content = pubspecFile.readAsStringSync();
      if (content.contains('publish_to: none')) continue;

      if (!content.contains('version:')) {
        formatter.writeln('ERROR: ${project.name} missing version field');
        issues++;
      }

      final changelog = File(p.join(project.path, 'CHANGELOG.md'));
      if (!changelog.existsSync()) {
        formatter.writeln('WARN: ${project.name} missing CHANGELOG.md');
        issues++;
      }
    }

    if (issues == 0) {
      formatter.writeln('Release plan check passed. All packages are ready.');
    } else {
      formatter.writeln('\n$issues issue(s) found.');
      throw const ProcessExit(1);
    }
  }

  String _findWorkspaceRoot() {
    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }
    return root;
  }
}
