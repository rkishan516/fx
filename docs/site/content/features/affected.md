---
title: Affected Analysis
description: Run tasks only on projects affected by git changes, dramatically reducing CI time and developer feedback loops.
---

# Affected Analysis

As your workspace grows, running every task on every project for every change becomes wasteful. If you changed one line in `shared`, why re-test `flutter_ui` which doesn't depend on it?

The `fx affected` command solves this. It determines which projects have been modified since a base git ref and runs tasks **only on those projects and their transitive dependents**.

## How It Looks

```text
$ fx affected --target test --base main

  Affected projects (3 of 12):
    shared        (directly changed)
    models        (depends on shared)
    app           (depends on models)

  Running test on 3 projects...

  ✓ shared:test     1.2s
  ✓ models:test     2.1s
  ✓ app:test        3.5s

  3/3 succeeded (9 projects skipped — not affected)
  Total: 6.8s (saved ~45s by skipping unaffected projects)
```

Compare this to `fx run-many --target test` which would run all 12 projects — affected analysis saved over 80% of the work.

## How It Works

The affected algorithm follows four steps:

### Step 1: Diff

fx runs a git diff between two refs to find changed files:

```text
git diff --name-only base...head
```

This produces a list like:

```text
packages/shared/lib/src/model.dart
packages/shared/test/model_test.dart
```

### Step 2: Map Files to Projects

Each changed file is mapped to the project that owns it based on directory structure:

```text
packages/shared/lib/src/model.dart  →  shared
packages/shared/test/model_test.dart  →  shared
```

Files outside any project directory (root-level files) are treated specially — see [Root-Level Changes](#root-level-changes).

### Step 3: Propagate Through the Graph

Using the project graph, fx walks forward from each directly changed project to find all transitive dependents:

```text
shared (changed)
  └── models (depends on shared → affected)
        └── app (depends on models → affected)
  └── flutter_ui (depends on shared → affected)
```

### Step 4: Filter by Input Patterns

Before running tasks, fx checks whether the changed files match the target's `inputs` patterns. If you changed `packages/shared/README.md` but your `test` target only watches `lib/**` and `test/**`, `shared` won't be marked as affected for the `test` target.

This prevents unnecessary rebuilds from documentation-only changes.

## Usage

### Basic Usage

```text
$ fx affected --target test --base main
```

### Multiple Targets

```text
$ fx affected --target test --target analyze --base main
```

### Against a Specific Commit

```text
$ fx affected --target test --base HEAD~5
$ fx affected --target test --base v1.0.0
$ fx affected --target test --base abc123f
```

### Custom Head Ref

By default, head is `HEAD` (your current working tree). Override it to compare two branches:

```text
$ fx affected --target test --base main --head feature-branch
```

### Include Uncommitted and Untracked Files

By default, fx only considers committed changes. Include working tree changes with:

```text
$ fx affected --target test --base main --uncommitted
$ fx affected --target test --base main --untracked
$ fx affected --target test --base main --uncommitted --untracked
```

This is useful during local development when you want to test changes before committing.

### Override with Explicit File List

Skip git entirely and specify which files changed:

```text
$ fx affected --target test --files "packages/core/lib/src/model.dart,packages/utils/lib/utils.dart"
```

This is useful in CI systems that provide their own change detection.

## Default Base Ref

Configure the default base ref so you don't need `--base` every time:

```yaml
fx:
  defaultBase: main
```

Now `fx affected --target test` implicitly uses `--base main`.

For teams using different branching strategies:

```yaml
fx:
  defaultBase: develop     # GitFlow
  defaultBase: trunk       # Trunk-based development
```

## Visualizing Affected Projects

### Affected Graph

See which projects are affected without running any tasks:

```text
$ fx graph --affected --base main

Affected projects (3 of 12):
  shared          (directly changed)
    └── models    (depends on shared)
         └── app  (depends on models)
  flutter_ui      (depends on shared)

9 projects not affected.
```

### Preview Execution Plan

```text
$ fx affected --target test --base main --graph

Execution plan (affected only):
  1. shared:test         (directly changed)
  2. models:test         (after shared, depends on shared)
  3. flutter_ui:test     (depends on shared, parallel with models)
  4. app:test            (after models)
```

## Root-Level Changes

Changes to files outside any project directory affect **all** projects. This includes:

| File | Why It Affects Everything |
|------|--------------------------|
| Root `pubspec.yaml` | Workspace configuration changed |
| `fx.yaml` | Target definitions, cache config changed |
| Root `analysis_options.yaml` | Linting rules affect all packages |
| `.fxignore` | File exclusion rules changed |
| CI configuration | Build environment changed |

To prevent root-level changes from triggering all projects, move configuration into individual project directories where possible, or use `.fxignore` to exclude files that don't affect builds.

## Input Matching

The affected algorithm respects target `inputs` patterns. Only files matching the target's inputs count as "changes" for that target:

```yaml
fx:
  targets:
    test:
      inputs:
        - lib/**
        - test/**
    analyze:
      inputs:
        - lib/**
        - analysis_options.yaml
```

If you change `packages/core/test/model_test.dart`:
- `core` is affected for `test` (matches `test/**`)
- `core` is **not** affected for `analyze` (doesn't match `lib/**` or `analysis_options.yaml`)

This fine-grained matching prevents unnecessary work.

## Combining with Other Features

### With Caching

Affected analysis and caching work together. Even among affected projects, some may have cached results:

```text
$ fx affected --target test --base main

  ✓ shared:test     1.2s
  ✓ models:test     replayed from cache (0.01s)
  ✓ app:test        3.5s
```

### With Distribution

Distribute affected work across CI matrix workers:

```text
$ fx affected --target test --base main --workers 4 --worker-index 0
```

### With Bail

Stop on first failure:

```text
$ fx affected --target test --base main --bail
```

## CI Configuration

### GitHub Actions

```yaml
name: CI
on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0    # Full history for accurate diff
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx affected --target test --base origin/main
```

<Info>
Always use `fetch-depth: 0` in CI. Without full git history, fx cannot compute accurate diffs and will fall back to running all projects.
</Info>

### GitLab CI

```yaml
test:
  script:
    - dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
    - fx affected --target test --base origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME
```

## CLI Options Reference

| Option | Description | Default |
|--------|-------------|---------|
| `--target <target>` | Target to run (required) | — |
| `--base <ref>` | Base git ref for comparison | From config (`defaultBase`) |
| `--head <ref>` | Head git ref | `HEAD` |
| `--files <files>` | Explicit comma-separated file list | — |
| `--uncommitted` | Include uncommitted changes | `false` |
| `--untracked` | Include untracked files | `false` |
| `--exclude <patterns>` | Exclude projects matching patterns | — |
| `--parallel <n>` | Concurrency limit | CPU cores |
| `--output-style <style>` | Output format: `stream`, `static`, `tui` | `static` |
| `--graph` | Preview execution plan without running | `false` |
| `--bail` | Stop on first failure | `false` |
| `--skip-cache` | Ignore cached results | `false` |
| `--workers <n>` | Total CI matrix workers | — |
| `--worker-index <i>` | This worker's index (0-based) | — |
| `--verbose` | Show detailed output including file-to-project mapping | `false` |

## Troubleshooting

### All Projects Marked as Affected

Common causes:

1. **Shallow clone** — CI checked out with limited depth. Use `fetch-depth: 0`
2. **Root-level file changed** — Changes to root `pubspec.yaml`, `fx.yaml`, etc. affect all projects
3. **Base ref doesn't exist** — The specified base branch hasn't been fetched. Run `git fetch origin main`

### No Projects Marked as Affected

1. **Wrong base ref** — Your changes may be relative to a different branch
2. **Input patterns too narrow** — Changed files don't match the target's `inputs` patterns
3. **Files outside project directories** — Changes to files not owned by any project are ignored (unless root-level)

Run with `--verbose` to see the file-to-project mapping and understand what fx detected.

## Learn More

- [Explore Your Workspace](/features/explore-your-workspace) — Visualize affected projects in the graph
- [Cache Task Results](/features/cache-task-results) — How caching complements affected analysis
- [Distribute Tasks](/features/distribute-tasks) — Split affected work across CI workers
- [CI Setup](/recipes/ci-setup) — Full CI configuration examples
