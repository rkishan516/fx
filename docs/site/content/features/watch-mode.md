---
title: Watch Mode
description: Automatically re-run targets when source files change for instant feedback during development.
---

# Watch Mode

During active development, the workflow of "edit code, switch to terminal, run tests, check results, switch back" creates friction. Watch mode eliminates this — fx monitors your files and automatically re-runs targets when something changes.

## How It Looks

```text
$ fx watch --target test

  Watching 8 projects for changes...

  [14:32:01] packages/shared/lib/src/model.dart changed
  [14:32:01] Running shared:test...
  [14:32:03] ✓ shared:test passed (1.8s)

  [14:32:15] packages/models/lib/src/user.dart changed
  [14:32:15] Running models:test...
  [14:32:17] ✓ models:test passed (2.1s)

  [14:32:45] packages/shared/lib/src/model.dart changed
  [14:32:45] Running shared:test...
  [14:32:46] ✗ shared:test FAILED (1.2s)
             Expected: 42
             Actual: 41

  Watching for changes... (Ctrl+C to stop)
```

## Usage

### Watch All Projects

```text
fx watch --target test
```

### Watch Specific Projects

```text
fx watch --target test --projects "packages/core"
fx watch --target test --projects "packages/core,packages/utils"
fx watch --target test --projects "packages/*"
```

### Watch Multiple Targets

```text
fx watch --target test --target analyze
```

When both are specified, a file change triggers both targets for the affected project.

## How It Works

1. **Setup** — fx sets up file system watchers on all project directories (or the specified subset)
2. **Detect** — When a file changes, fx identifies which project owns the file
3. **Propagate** — If the changed project has dependents and the target uses `dependsOn` with `^`, dependent project targets may also re-run
4. **Debounce** — Rapid successive changes (like saving multiple files) are debounced into a single run
5. **Execute** — The target runs on affected projects, respecting dependency order
6. **Report** — Results are displayed inline in the terminal

## Cache Integration

Watch mode works with caching. When a file changes, only that project's cache is invalidated. Unchanged projects still benefit from cached results:

```text
[14:32:01] packages/shared/lib/src/model.dart changed
[14:32:01] Running test on affected projects...
  ✓ shared:test          1.8s (cache invalidated — re-ran)
  ✓ models:test          replayed from cache (0.01s)
  ✓ app:test             replayed from cache (0.01s)
```

<Info>
Watch mode combined with caching gives you the fastest possible feedback loop. Only the code you just changed gets re-tested, while everything else replays from cache.
</Info>

## Dependency Propagation

When project `shared` changes and `models` depends on `shared`:

- **Without `dependsOn: [^test]`** — Only `shared:test` re-runs
- **With `dependsOn: [^test]`** — Both `shared:test` and `models:test` re-run (in order)

Configure this in your target pipeline:

```yaml
fx:
  targets:
    test:
      dependsOn:
        - ^test    # Also re-test projects that depend on the changed project
```

## Output Styles

Watch mode supports the same output styles as regular task execution:

```text
fx watch --target test --output-style stream    # Real-time output
fx watch --target test --output-style static    # Results after completion
fx watch --target test --output-style tui       # Interactive terminal UI
```

## Ignoring Files

Watch mode respects your `.fxignore` patterns and the target's `inputs` configuration. Changes to files outside the input patterns don't trigger re-runs:

```yaml
fx:
  targets:
    test:
      inputs:
        - lib/**
        - test/**
        - "!**/*.md"    # README changes won't trigger test re-runs
```

## When to Use Watch Mode

| Scenario | Command |
|----------|---------|
| TDD workflow | `fx watch --target test --projects packages/core` |
| Lint while coding | `fx watch --target analyze` |
| Build on change | `fx watch --target build` |
| Full feedback loop | `fx watch --target test --target analyze` |

## Learn More

- [Run Tasks](/features/run-tasks) — How task execution works
- [Cache Task Results](/features/cache-task-results) — How caching integrates with watch
- [Task Pipeline Configuration](/concepts/task-pipeline-configuration) — Configure `dependsOn` for propagation
- [Workspace Watching](/recipes/workspace-watching) — Advanced watch configuration
