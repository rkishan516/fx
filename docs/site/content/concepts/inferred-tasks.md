---
title: Inferred Tasks
description: How fx automatically detects targets from your project structure without explicit configuration.
---

# Inferred Tasks

One of fx's design goals is **zero-configuration for common cases**. When you add a new package to your workspace, fx automatically detects what tasks it supports by looking at its file structure.

This means many projects work out of the box — no target configuration needed.

## Auto-Detection Rules

| File/Directory | Inferred Target | Executor | Default Inputs |
|----------------|----------------|----------|----------------|
| `test/` | `test` | `dart test` | `lib/**`, `test/**` |
| `analysis_options.yaml` | `analyze` | `dart analyze` | `lib/**` |
| `lib/` | `format` | `dart format .` | `lib/**`, `test/**` |
| `bin/` (Dart CLI) | `compile` | `dart compile exe` | `lib/**`, `bin/**` |
| `integration_test/` (Flutter) | `integration_test` | `flutter test integration_test` | `lib/**`, `integration_test/**` |
| `build.yaml` | `build` | `dart run build_runner build` | `lib/**`, `build.yaml` |

## How It Works

During project discovery, `ProjectDiscovery` scans each project directory:

```text
packages/core/
  ├── lib/           → infers "format" target
  ├── test/          → infers "test" target
  ├── build.yaml     → infers "build" target
  └── analysis_options.yaml  → infers "analyze" target

Inferred targets for core: test, analyze, format, build
```

You can see what fx inferred with:

```text
$ fx show core --targets

  Project: core
  Type: dart_package

  Targets:
    test     → dart test            (inferred, cached)
    analyze  → dart analyze         (inferred, cached)
    format   → dart format .        (inferred, cached)
    build    → dart run build_runner build  (inferred, cached)
```

## Priority and Overriding

Inferred targets have the **lowest priority**. They're overridden by explicit configuration:

| Priority | Source | When Used |
|----------|--------|-----------|
| 1 (lowest) | Inferred from file structure | No explicit config exists |
| 2 | Workspace `targetDefaults` | Provides defaults for all projects |
| 3 | Workspace `targets` | Explicit workspace-level definition |
| 4 (highest) | Project `fx.targets` | Per-project override |

This means:
- If you don't configure anything, inferred targets work automatically
- If you define a `test` target in your workspace config, it replaces the inferred one for all projects
- If a project defines its own `test` target, it overrides everything else for that project

### Example: Overriding an Inferred Target

The inferred `test` target runs `dart test`. To add coverage:

```yaml
# packages/core/pubspec.yaml
fx:
  targets:
    test:
      executor: dart test --coverage --concurrency=4
      inputs:
        - lib/**
        - test/**
        - fixtures/**    # This project has test fixtures
```

## Flutter Routing

When a project is detected as a Flutter project (has `flutter` dependency in `pubspec.yaml`), fx automatically routes Dart commands to their Flutter equivalents:

| Dart Command | Flutter Equivalent | When Routed |
|-------------|-------------------|-------------|
| `dart test` | `flutter test` | Project has `flutter` dependency |
| `dart analyze` | `flutter analyze` | Project has `flutter` dependency |
| `dart compile exe` | `flutter build` | Project has `flutter` dependency |
| `dart format .` | `dart format .` (unchanged) | Format is the same for both |
| `dart run build_runner build` | `dart run build_runner build` (unchanged) | build_runner works the same |

This routing happens automatically — you don't need separate target definitions for Dart and Flutter projects.

```text
$ fx show mobile_app --targets

  Project: mobile_app
  Type: flutter_app

  Targets:
    test     → flutter test         (inferred, Flutter-routed)
    analyze  → flutter analyze      (inferred, Flutter-routed)
    format   → dart format .        (inferred)
```

## Disabling Inference

To disable inference and only use explicitly configured targets:

```yaml
fx:
  targets:
    test:
      executor: dart test
    analyze:
      executor: dart analyze
    # Only these two targets are available — no inferred targets
```

When you explicitly define targets in your workspace config, only those targets are used. Inferred targets for target names that aren't in the explicit config are still added, but explicit definitions always take precedence.

## Dynamic Dependencies

Enable import-based dependency detection to find undeclared workspace dependencies:

```yaml
fx:
  dynamicDependencies: true
```

When enabled, the `ImportAnalyzer` scans Dart source files for `import 'package:...'` statements and detects workspace packages that are imported but not declared in `pubspec.yaml`:

```text
$ fx graph --detect-implicit

  Implicit dependencies found:
    utils imports 'package:shared' but doesn't declare it in pubspec.yaml

  These dependencies affect task ordering but aren't in the project graph.
  Add them to pubspec.yaml for correct build behavior.
```

This helps catch "it works on my machine" bugs where a package relies on a transitive dependency that happens to be available locally but isn't properly declared.

## Learn More

- [Run Tasks](/features/run-tasks) — How to execute inferred targets
- [Types of Configuration](/concepts/configuration) — Explicit target configuration
- [Executors](/concepts/executors) — How executors are resolved
