---
title: Workspace Watching
description: Configure and use file watching for automatic task re-execution during development.
---

# Workspace Watching

File watching automates the "save → switch to terminal → run → check results" loop. fx monitors your workspace and re-runs targets when source files change.

## Basic Usage

```text
$ fx watch --target test

  Watching 8 projects for changes...

  [14:32:01] packages/shared/lib/src/model.dart changed
  [14:32:01] Running shared:test...
  [14:32:03] ✓ shared:test passed (1.8s)

  [14:32:15] packages/models/lib/src/user.dart changed
  [14:32:15] Running models:test...
  [14:32:17] ✓ models:test passed (2.1s)

  Watching for changes... (Ctrl+C to stop)
```

## Watch Specific Projects

Focus on the projects you're actively developing:

```text
# Watch a single project
fx watch --target test --projects "packages/core"

# Watch multiple projects
fx watch --target test --projects "packages/core,packages/utils"

# Watch with glob patterns
fx watch --target test --projects "packages/*"
```

## Watch Multiple Targets

```text
fx watch --target test --target analyze
```

When both are specified, a file change triggers both targets for the affected project.

## How It Works

1. **Setup** — fx sets up file system watchers on project directories
2. **Detect** — When a file changes, fx identifies which project owns it
3. **Debounce** — Rapid changes (saving multiple files) are collected into a single run
4. **Filter** — Only changes matching the target's `inputs` patterns trigger re-runs
5. **Execute** — The target runs on the affected project
6. **Propagate** — If configured with `dependsOn: [^target]`, dependent projects also re-run

## Integration with Caching

Watch mode works with the cache system:

```text
[14:32:01] packages/shared/lib/src/model.dart changed
[14:32:01] Running test on affected projects...
  ✓ shared:test          1.8s (re-ran — cache invalidated)
  ✓ models:test          replayed from cache (0.01s)
  ✓ app:test             replayed from cache (0.01s)
```

Only the changed project's cache is invalidated. Unchanged projects still use cached results.

## Common Workflows

### TDD

```text
fx watch --target test --projects packages/core
```

Edit code → tests run automatically → see results immediately.

### Continuous Analysis

```text
fx watch --target analyze
```

Get instant feedback on analysis issues as you code.

### Build on Change

```text
fx watch --target build --projects packages/models
```

Automatically regenerate code when source files change.

### Full Feedback Loop

```text
fx watch --target test --target analyze --target format
```

Run all quality checks on every save.

## File Filtering

Watch mode respects your target's `inputs` configuration and `.fxignore`. Changes to files outside these patterns don't trigger re-runs:

```yaml
fx:
  targets:
    test:
      inputs:
        - lib/**
        - test/**
        - "!**/*.md"    # README changes won't trigger re-runs
```

## Learn More

- [Watch Mode](/features/watch-mode) — Feature overview
- [Run Tasks](/features/run-tasks) — How task execution works
- [Cache Task Results](/features/cache-task-results) — How caching integrates with watch
