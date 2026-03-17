---
title: Manage Releases
description: Coordinate versioning, changelogs, and git tags across workspace packages with flexible release strategies.
---

# Manage Releases

Releasing packages from a monorepo is more complex than a single-package release. Packages may need to version together, changelogs must reflect changes across the workspace, and git tags need to identify which packages were released.

fx's release system handles this coordination — from version bumps to changelog generation to git tagging.

## How It Looks

```text
$ fx release

  Analyzing changes since v1.1.0...

  Projects with changes:
    fx_core      3 commits (2 features, 1 fix)
    fx_graph     1 commit (1 fix)
    fx_runner    2 commits (1 feature, 1 fix)

  Version plan (fixed relationship):
    v1.1.0 → v1.2.0 (minor bump — new features detected)

  Updating versions...
    ✓ fx_core/pubspec.yaml       1.1.0 → 1.2.0
    ✓ fx_graph/pubspec.yaml      1.1.0 → 1.2.0
    ✓ fx_runner/pubspec.yaml     1.1.0 → 1.2.0

  Generating changelogs...
    ✓ fx_core/CHANGELOG.md
    ✓ fx_graph/CHANGELOG.md
    ✓ fx_runner/CHANGELOG.md
    ✓ CHANGELOG.md (workspace)

  Git operations:
    ✓ Committed: "chore(release): v1.2.0"
    ✓ Tagged: v1.2.0

  Release complete: v1.2.0
```

## Configuration

Configure release behavior in your root `pubspec.yaml` or `fx.yaml`:

```yaml
fx:
  releaseConfig:
    projectsRelationship: fixed
    releaseTagPattern: "v{version}"
    changelog:
      projectChangelogs: true
      workspaceChangelog: true
    git:
      commit: true
      commitMessage: "chore(release): v{version}"
      tag: true
    versionBump:
      conventionalCommits: true
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `projectsRelationship` | `fixed` or `independent` | `fixed` |
| `releaseTagPattern` | Git tag format | `v{version}` |
| `changelog.projectChangelogs` | Generate per-project changelogs | `true` |
| `changelog.workspaceChangelog` | Generate root changelog | `true` |
| `git.commit` | Auto-commit version changes | `true` |
| `git.commitMessage` | Commit message template | `chore(release): v{version}` |
| `git.tag` | Create git tag | `true` |
| `versionBump.conventionalCommits` | Use commit messages to determine bump type | `true` |

## Release Commands

### Automatic Version Detection

```text
$ fx release
```

Analyzes commits since the last release tag and determines the appropriate version bump based on conventional commit messages:

| Commit Prefix | Bump Type |
|---------------|-----------|
| `feat:` | Minor (1.0.0 → 1.1.0) |
| `fix:` | Patch (1.0.0 → 1.0.1) |
| `BREAKING CHANGE:` or `!:` | Major (1.0.0 → 2.0.0) |

### Explicit Version

```text
$ fx release --version 2.0.0
$ fx release --version major
$ fx release --version minor
$ fx release --version patch
$ fx release --version premajor --preid beta
```

### From a Specific Tag

```text
$ fx release --from v1.0.0
```

Analyzes changes from the specified tag instead of auto-detecting the last release.

### Dry Run

Preview what would happen without making changes:

```text
$ fx release --dry-run

  DRY RUN — no files will be modified

  Would bump: 1.1.0 → 1.2.0
  Would update 3 pubspec.yaml files
  Would generate 4 changelogs
  Would commit: "chore(release): v1.2.0"
  Would tag: v1.2.0
```

## Release Groups

In larger workspaces, you may want different packages to follow different versioning strategies. Release groups let you coordinate this:

```yaml
fx:
  releaseConfig:
    groups:
      core-packages:
        projects:
          - fx_core
          - fx_graph
          - fx_runner
          - fx_cache
        projectsRelationship: fixed
        releaseTagPattern: "core-v{version}"
      plugins:
        projects:
          - fx_generator
        projectsRelationship: independent
        releaseTagPattern: "{projectName}-v{version}"
      cli:
        projects:
          - fx_cli
        projectsRelationship: independent
```

### Fixed Relationship

All projects in the group share the same version number. When any project changes, all get the same version bump:

```text
$ fx release --group core-packages

  All core-packages: 1.1.0 → 1.2.0
    ✓ fx_core/pubspec.yaml
    ✓ fx_graph/pubspec.yaml
    ✓ fx_runner/pubspec.yaml
    ✓ fx_cache/pubspec.yaml
```

This is ideal for tightly coupled packages that should always be used together.

### Independent Relationship

Each project versions independently based on its own changes:

```text
$ fx release --group plugins

  fx_generator: 0.8.0 → 0.9.0  (new features)
```

This is ideal for packages with separate consumers and release cadences.

## Changelog Generation

fx generates changelogs from conventional commit messages:

```text
## 1.2.0 (2026-03-16)

### Features

- **fx_core:** Added support for named configurations (#142)
- **fx_runner:** Batch execution mode for independent tasks (#156)

### Bug Fixes

- **fx_graph:** Fixed cycle detection for self-referencing projects (#148)
- **fx_runner:** Correct exit code on partial failure (#151)
```

### Per-Project Changelogs

When `projectChangelogs: true`, each project gets its own `CHANGELOG.md` with only its changes:

```text
# packages/fx_core/CHANGELOG.md
## 1.2.0 (2026-03-16)

### Features
- Added support for named configurations (#142)
```

## Release Workflow

A typical release workflow:

```text
# 1. Preview what will be released
$ fx release --dry-run

# 2. Run all tests on affected projects
$ fx affected --target test --base <last-release-tag>

# 3. Execute the release
$ fx release

# 4. Push commits and tags
$ git push --follow-tags
```

### CI Release Automation

```yaml
# GitHub Actions
name: Release
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version bump type'
        required: true
        default: 'auto'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx release --version ${{ github.event.inputs.version }}
      - run: git push --follow-tags
```

## Learn More

- [CI Setup](/recipes/ci-setup) — Automate releases in CI
- [Affected Analysis](/features/affected) — Test only what changed before releasing
- [Workspace Configuration](/reference/workspace-configuration) — Full release config schema
