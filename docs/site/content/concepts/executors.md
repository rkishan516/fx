---
title: Executors and Configurations
description: How fx resolves and runs target executors — from simple shell commands to custom plugins.
---

# Executors and Configurations

An **executor** is the command that implements a target. When you run `fx run core test`, fx needs to know *what* to actually execute. That's the executor's job.

## String Executors

The simplest and most common executor is a shell command string:

```yaml
fx:
  targets:
    test:
      executor: dart test
    build:
      executor: dart run build_runner build --delete-conflicting-outputs
    lint:
      executor: dart analyze --fatal-infos
    format:
      executor: dart format --set-exit-if-changed .
```

The `TaskExecutor` splits the executor string and runs it via `ProcessRunner` in the project's directory. The command inherits the project's working directory, so relative paths work correctly.

```text
$ fx run core test

  Running in packages/core/:
  > dart test
  00:01 +24: All tests passed!
```

## Plugin Executors

For complex logic that can't be expressed as a single shell command, use plugin executors with the `plugin:` prefix:

```yaml
fx:
  targets:
    build:
      executor: "plugin:custom_builder"
      options:
        optimize: true
        target: web
        outputDir: build/web
```

Plugin executors are Dart classes that implement the `ExecutorPlugin` interface. They receive the full target configuration, including options, and can run arbitrary logic.

See [Executor Plugins](/extending/executor-plugins) for how to build them.

## Executor Resolution Chain

When fx needs the executor for a specific project and target, it resolves through a chain:

```text
1. Project-level target     →  packages/core/pubspec.yaml fx.targets.test.executor
2. Workspace-level target   →  fx.yaml targets.test.executor
3. Target defaults          →  fx.yaml targetDefaults.test.executor
4. Inferred target          →  Auto-detected from project structure
5. Flutter routing          →  Dart → Flutter command mapping
```

The first match wins. This means a project can override the workspace executor, the workspace can override defaults, and defaults override inferred targets.

### Example Resolution

```yaml
# fx.yaml (workspace)
fx:
  targetDefaults:
    test:
      executor: dart test          # Priority 3

  targets:
    test:
      executor: dart test --reporter expanded  # Priority 2
```

```yaml
# packages/special/pubspec.yaml (project)
fx:
  targets:
    test:
      executor: dart test --coverage --concurrency=1  # Priority 1 (wins)
```

For `special`, the executor is `dart test --coverage --concurrency=1`.
For all other projects, the executor is `dart test --reporter expanded`.

## Flutter Routing

When a project is detected as a Flutter project (has `flutter` in its `pubspec.yaml` dependencies), fx automatically maps Dart commands to Flutter equivalents:

| Dart Executor | Flutter Equivalent | Notes |
|--------------|-------------------|-------|
| `dart test` | `flutter test` | Flutter test runner includes widget testing |
| `dart analyze` | `flutter analyze` | Flutter analyzer includes Flutter-specific rules |
| `dart compile exe` | `flutter build` | Different build system |
| `dart format .` | `dart format .` | Same command (no routing needed) |

This routing is transparent — you define targets once with Dart commands, and Flutter projects automatically use the right tool.

```yaml
# This single definition works for both Dart and Flutter projects:
fx:
  targets:
    test:
      executor: dart test
```

```text
$ fx run dart_package test   →  runs "dart test"
$ fx run flutter_app test    →  runs "flutter test" (auto-routed)
```

## Executor Options

Targets can pass arbitrary options to their executor:

```yaml
fx:
  targets:
    test:
      executor: dart test
      options:
        coverage: true
        concurrency: 4
        batchable: true
```

For **string executors**, most options are informational — they don't affect the command. The exception is `batchable`, which controls whether the target can be batch-executed.

For **plugin executors**, the full `options` map is passed to the plugin's `execute` method, giving plugins full access to configuration.

### Reserved Options

| Option | Effect | Applies To |
|--------|--------|-----------|
| `batchable` | Controls batch execution eligibility | All executors |

## Named Configurations

Override executor settings per-environment:

```yaml
fx:
  targets:
    test:
      executor: dart test

  configurations:
    ci:
      skipCache: true
      targets:
        test:
          executor: dart test --reporter github
    coverage:
      targets:
        test:
          executor: dart test --coverage
    verbose:
      targets:
        test:
          executor: dart test --reporter expanded --chain-stack-traces
```

```text
$ fx run core test                        # dart test
$ fx run core test --configuration ci     # dart test --reporter github
$ fx run core test --configuration coverage  # dart test --coverage
```

Configurations are merged on top of the base config, so only the overridden values change.

## Learn More

- [Executor Plugins](/extending/executor-plugins) — Build custom executors
- [Inferred Tasks](/concepts/inferred-tasks) — How executors are auto-detected
- [Types of Configuration](/concepts/configuration) — Full configuration schema
- [Batch Execution](/features/batch-execution) — How the `batchable` option works
