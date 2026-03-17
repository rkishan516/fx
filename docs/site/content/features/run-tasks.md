---
title: Run Tasks
description: Execute targets across workspace projects with dependency ordering, parallelism, and caching.
---

# Run Tasks

In a monorepo, managing task execution across multiple projects requires tooling that understands dependencies, enables parallelism, and avoids redundant work. fx's task runner handles all of this.

## Defining Tasks

Tasks (called **targets**) come from three sources, merged in priority order:

### 1. Inferred from Project Structure

fx automatically detects targets from your project's files — no configuration needed:

| File/Directory | Inferred Target | Command |
|----------------|----------------|---------|
| `test/` | `test` | `dart test` / `flutter test` |
| `analysis_options.yaml` | `analyze` | `dart analyze` |
| `lib/` | `format` | `dart format .` |
| `bin/` | `compile` | `dart compile exe` |
| `build.yaml` | `build` | `dart run build_runner build` |
| `integration_test/` | `integration_test` | `flutter test integration_test` |

Learn more in [Inferred Tasks](/concepts/inferred-tasks).

### 2. Workspace Configuration

Define targets in your root `pubspec.yaml` or `fx.yaml`:

```yaml
fx:
  targets:
    test:
      executor: dart test
      inputs:
        - lib/**
        - test/**
      cache: true
    build:
      executor: dart run build_runner build
      inputs:
        - lib/**
        - build.yaml
      outputs:
        - lib/**/*.g.dart
```

### 3. Per-Project Overrides

Override workspace targets for individual projects in their `pubspec.yaml`:

```yaml
# packages/special/pubspec.yaml
fx:
  targets:
    test:
      executor: dart test --coverage --concurrency=1
```

Project-level targets take the highest priority. See [Types of Configuration](/concepts/configuration) for the full resolution chain.

## Running a Single Task

```text
$ fx run header test

> Running "dart test" for header...
> 00:01 +12: All tests passed!

header:test completed in 1.2s
```

## Running Tasks Across Projects

The `run-many` command executes a target on all (or selected) projects:

```text
$ fx run-many --target test

  ✓ shared:test          1.2s
  ✓ utils:test           1.4s
  ✓ models:test          2.1s
  ✓ app:test             3.5s

  4/4 succeeded
```

### Run Multiple Targets

```text
fx run-many --target test --target lint
```

### Select Specific Projects

```text
fx run-many --target test --projects "packages/core,packages/utils"
fx run-many --target test --projects "packages/*"
fx run-many --target test --exclude "packages/legacy_*"
```

### Run on Affected Projects Only

```text
fx affected --target test --base main
```

Only projects changed since the `main` branch (and their transitive dependents) are tested. See [Affected Analysis](/features/affected).

## Parallel Execution

fx runs independent tasks in parallel while respecting dependency order. By default, it uses the number of available CPU cores.

```text
fx run-many --target test --concurrency 4
```

The parallel runner is dependency-aware:

```text
# Given: app → models → shared
# fx runs:
#   1. shared (no deps)
#   2. models (waits for shared)    } in parallel where possible
#   3. app (waits for models)
#
# Independent projects (e.g., utils) run immediately
```

<Info>
fx's parallel runner uses a ready-queue pattern: only projects whose dependencies have all completed are eligible to start. This ensures correctness while maximizing parallelism.
</Info>

## Task Pipeline Configuration

Projects often need tasks to run in a specific order. Configure this with `dependsOn`:

```yaml
fx:
  targets:
    test:
      dependsOn:
        - build
```

Now `fx run core test` automatically runs `build` on `core` first.

### Transitive Dependencies with `^`

The `^` prefix means "run this target on all **dependency projects** first":

```yaml
fx:
  targets:
    test:
      dependsOn:
        - build          # build THIS project first
        - ^build         # build all DEPENDENCIES first
```

Given `app → models → shared`, running `fx run app test` executes:

1. `build` on `shared`
2. `build` on `models`
3. `build` on `app`
4. `test` on `app`

Learn more in [Task Pipeline Configuration](/concepts/task-pipeline-configuration).

## Terminal UI

fx includes a live terminal UI with spinner animation showing per-project status:

```text
$ fx run-many --target test --output-style tui

⠸ Running 4 tasks...
  ✓ shared:test          1.2s
  ✓ utils:test           1.4s
  ⠹ models:test          running...
  ⠋ app:test             pending (waiting for models)
```

### Output Styles

| Style | Behavior |
|-------|----------|
| `stream` | Stream output in real-time as tasks run |
| `static` | Show results after each task completes |
| `tui` | Interactive terminal UI with spinners |

```text
fx run-many --target test --output-style stream
```

## Bail on First Failure

Stop all execution when the first task fails:

```text
fx run-many --target test --bail
```

Without `--bail`, fx runs all tasks and reports failures at the end.

## Root-Level Scripts

Define workspace-level commands that aren't tied to any project:

```yaml
fx:
  scripts:
    check: "fx run-many --target test && fx analyze"
    ci: "fx affected --target test --base origin/main --bail"
```

```text
$ fx run :check
$ fx run :ci
```

See [Root-Level Scripts](/recipes/root-level-scripts) for more examples.

## Preview Execution Plan

See which tasks would run without executing them:

```text
$ fx run-many --target test --graph

Execution plan:
  1. shared:test
  2. utils:test     (parallel with shared)
  3. models:test    (after shared)
  4. app:test       (after models)
```

## Skip Cache

Force re-execution even when cached results exist:

```text
fx run-many --target test --skip-cache
```

## Distributed Execution

Split work across CI matrix workers:

```text
fx run-many --target test --workers 4 --worker-index 0
```

See [Distribute Tasks](/features/distribute-tasks) for CI configuration examples.

## Learn More

- [Cache Task Results](/features/cache-task-results) — How caching works with task execution
- [Affected Analysis](/features/affected) — Run only what changed
- [Task Pipeline Configuration](/concepts/task-pipeline-configuration) — Configure `dependsOn` chains
- [Batch Execution](/features/batch-execution) — Combine tasks for reduced overhead
- [CLI Commands Reference](/reference/commands) — Full `fx run` and `fx run-many` options
