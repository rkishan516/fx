---
title: Task Pipeline Configuration
description: Configure target dependencies and execution order with dependsOn for correct, efficient task orchestration.
---

# Task Pipeline Configuration

In a monorepo, tasks often depend on other tasks. You can't test code that uses generated models unless the models are generated first. You can't deploy unless tests pass.

Task pipelines define these relationships with `dependsOn`, ensuring fx runs tasks in the correct order automatically.

## Basic Dependencies

```yaml
fx:
  targets:
    test:
      executor: dart test
      dependsOn:
        - build           # Run build before test
    build:
      executor: dart run build_runner build
```

When you run `fx run core test`, fx automatically runs `core:build` first, then `core:test`.

```text
$ fx run core test

  ✓ core:build    2.1s
  ✓ core:test     1.8s

  Pipeline completed in 3.9s
```

## Transitive Dependencies with `^`

The `^` prefix means "run this target on all **dependency projects** first":

```yaml
fx:
  targets:
    test:
      dependsOn:
        - build         # Run build on THIS project
        - ^build        # Run build on all DEPENDENCY projects first
```

This is the most powerful feature of task pipelines. Given `app → models → shared`:

```text
$ fx run app test

  Pipeline resolution:
    1. shared:build     (dependency of models, which is dependency of app)
    2. models:build     (dependency of app)
    3. app:build        (same project, dependsOn: build)
    4. app:test         (requested target)

  ✓ shared:build    0.8s
  ✓ models:build    1.2s
  ✓ app:build       2.1s
  ✓ app:test        3.5s
```

Without `^build`, only steps 3 and 4 would run — dependency projects wouldn't build first, potentially causing test failures if they need generated code.

### When to Use `^`

| Scenario | Use `^`? | Why |
|----------|----------|-----|
| Tests need generated code from dependencies | Yes (`^build`) | Dependencies must generate code first |
| Tests are self-contained | No | No cross-project dependency |
| Deployment needs all deps built | Yes (`^build`) | Full build chain required |
| Linting is per-project only | No | Each project lints independently |

## Pipeline Resolution

The `TaskPipeline` resolves targets using depth-first traversal:

1. Start with the requested target on the requested project
2. For each `dependsOn` entry:
   - **Plain target** (e.g., `build`): add to pipeline for the same project
   - **`^target`** (e.g., `^build`): add to pipeline for all dependency projects in the graph
3. Recursively resolve `dependsOn` for each added target
4. Detect circular target dependencies
5. Return the topologically ordered list

### Circular Detection

Circular target dependencies are detected and reported:

```text
$ fx run core test

  Error: Circular target dependency detected:
    test → build → test

  Fix the cycle in your target configuration.
```

This catches configuration errors early, before any task executes.

## Multiple Dependencies

A target can depend on multiple other targets:

```yaml
fx:
  targets:
    deploy:
      executor: ./scripts/deploy.sh
      cache: false
      dependsOn:
        - build
        - test
        - lint
```

Dependencies are resolved in the order listed. If `build`, `test`, and `lint` are independent of each other, they can run in parallel — fx only waits for all to complete before starting `deploy`.

```text
$ fx run app deploy

  ✓ app:build     2.1s  ┐
  ✓ app:test      3.5s  ├── parallel
  ✓ app:lint      0.8s  ┘
  ✓ app:deploy    5.2s  ←── after all three

  Pipeline completed in 8.7s
```

## Per-Project Target Overrides

Individual projects can override workspace targets, including their `dependsOn`:

```yaml
# packages/special/pubspec.yaml
fx:
  targets:
    test:
      executor: dart test --coverage
      dependsOn:
        - generate        # This project needs code generation before testing
```

This override completely replaces the workspace-level `test` target for the `special` project. Other projects continue using the workspace definition.

## Target Resolution Order

Targets are merged from three levels:

| Priority | Source | Description |
|----------|--------|-------------|
| 1 (lowest) | `targetDefaults` | Fallback values for all targets |
| 2 | `targets` | Workspace-level definitions |
| 3 (highest) | Project `fx.targets` | Per-project overrides |

```yaml
fx:
  targetDefaults:
    test:
      cache: true           # Default: cache all test targets

  targets:
    test:
      executor: dart test
      inputs: [lib/**, test/**]
      dependsOn: [build]    # Workspace default: build before test
```

```yaml
# packages/simple/pubspec.yaml — uses workspace defaults
# packages/special/pubspec.yaml — overrides:
fx:
  targets:
    test:
      executor: dart test --coverage --concurrency=1
      dependsOn: []         # No build step needed for this project
```

## Common Pipeline Patterns

### Build-Then-Test

```yaml
fx:
  targets:
    test:
      dependsOn: [build]
    build:
      executor: dart run build_runner build
```

### Full CI Pipeline

```yaml
fx:
  targets:
    ci:
      executor: echo "CI passed"
      dependsOn: [test, analyze, format-check]
    test:
      dependsOn: [^build, build]
    analyze:
      executor: dart analyze
    format-check:
      executor: dart format --set-exit-if-changed .
    build:
      executor: dart run build_runner build
```

### Deploy Pipeline

```yaml
fx:
  targets:
    deploy:
      executor: ./scripts/deploy.sh
      cache: false
      dependsOn: [build, test]
    build:
      dependsOn: [^build]
    test:
      dependsOn: [^test, build]
```

<Info>
Circular target dependencies (test depends on build depends on test) are detected and reported as errors during pipeline resolution. Fix the cycle by removing one direction of the dependency.
</Info>

## Learn More

- [Run Tasks](/features/run-tasks) — How task execution uses pipelines
- [Mental Model](/concepts/mental-model) — How pipelines fit into the overall architecture
- [Types of Configuration](/concepts/configuration) — Where pipeline config lives
