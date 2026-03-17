---
title: Batch Execution
description: Combine independent projects into single process calls for reduced overhead and faster execution.
---

# Batch Execution

Every process has startup overhead — loading the Dart VM, resolving packages, initializing test frameworks. When you have 20 packages that each run `dart test`, that's 20 cold starts.

Batch execution groups independent projects that share the same executor into a **single process call**, eliminating redundant startup costs.

## How It Looks

### Without Batch Mode

```text
$ fx run-many --target test

  Starting dart test for shared...       (1.2s startup + 0.5s tests)
  Starting dart test for utils...        (1.2s startup + 0.3s tests)
  Starting dart test for models...       (1.2s startup + 0.8s tests)
  Starting dart test for helpers...      (1.2s startup + 0.2s tests)

  Total: 6.4s (4.8s in startup overhead)
```

### With Batch Mode

```text
$ fx run-many --target test

  Batching 4 projects with "dart test"...
  dart test packages/shared packages/utils packages/models packages/helpers

  Total: 2.8s (1.2s startup + 1.6s tests)
  Saved: 3.6s by batching
```

One startup instead of four — **56% faster** in this example.

## How It Works

The `BatchGrouper` analyzes the execution plan and groups projects that meet all of these criteria:

1. **Same executor** — Projects must resolve to the same command (e.g., `dart test`)
2. **Independent** — No dependency edges between projects in the batch (otherwise execution order matters)
3. **Batchable** — The target's `batchable` option is not set to `false`
4. **At least 2 projects** — A single project doesn't benefit from batching

When conditions are met, fx combines the projects into a single command invocation:

```text
# Individual calls:
dart test packages/shared
dart test packages/utils
dart test packages/helpers

# Batched call:
dart test packages/shared packages/utils packages/helpers
```

## Default Batchable Executors

These executors support batching out of the box:

| Executor | Batched Form |
|----------|-------------|
| `dart test` | `dart test <dir1> <dir2> <dir3>` |
| `dart analyze` | `dart analyze <dir1> <dir2> <dir3>` |
| `flutter test` | `flutter test <dir1> <dir2> <dir3>` |
| `dart format .` | `dart format <dir1> <dir2> <dir3>` |

## Mixed Execution

Not all projects in a run may be batchable. fx automatically handles the mix:

```text
$ fx run-many --target test

  Batch 1 (dart test): shared, utils, helpers    →  single process
  Individual: app (depends on models — not batchable)
  Individual: models (depends on shared — not batchable)

  Execution order:
    1. Batch 1: shared + utils + helpers (parallel, batched)
    2. models:test (after shared completes)
    3. app:test (after models completes)
```

Projects with dependency relationships run individually to maintain correct ordering. Independent projects batch together.

## Disabling Batch for a Target

Some targets don't work correctly when batched — for example, tests that rely on process-level global state:

```yaml
fx:
  targets:
    test:
      executor: dart test
      options:
        batchable: false    # Always run individually
```

### Per-Project Override

```yaml
# packages/special/pubspec.yaml
fx:
  targets:
    test:
      options:
        batchable: false    # This project's tests need isolation
```

## When Batching Helps Most

| Scenario | Benefit |
|----------|---------|
| Many small packages (< 1s test time each) | High — startup dominates |
| Few large packages (> 30s test time each) | Low — startup is negligible |
| `dart analyze` across workspace | High — analyzer init is expensive |
| `dart format` across workspace | High — formatter init is fast but adds up |
| Tests with global state or port conflicts | Don't batch — use `batchable: false` |

## Combining with Other Features

Batch execution works alongside caching and affected analysis:

```text
$ fx affected --target test --base main

  Affected: shared, models, utils, helpers, app
  Cached: utils, helpers (replayed from cache)
  Running: shared, models, app

  Batch 1: shared (only independent affected project without deps)
  Individual: models (after shared)
  Individual: app (after models)
```

Cached projects are skipped entirely — they don't participate in batching.

## Learn More

- [Run Tasks](/features/run-tasks) — How task execution works
- [Cache Task Results](/features/cache-task-results) — Caching integrates with batch execution
- [Distribute Tasks](/features/distribute-tasks) — Distribute batched work across CI workers
