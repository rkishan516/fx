---
title: Add to Existing Project
description: Adopt fx in an existing Dart/Flutter monorepo.
---

# Add fx to an Existing Project

If you already have a Dart workspace or multi-package repository, you can adopt fx without restructuring your code.

## Step 1: Add the fx Configuration

Add an `fx:` section to your root `pubspec.yaml`:

```yaml
name: my_workspace
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
  - packages/core
  - packages/utils
  - packages/app

fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
      inputs:
        - lib/**
        - test/**
    analyze:
      executor: dart analyze
      inputs:
        - lib/**
    format:
      executor: dart format .
      inputs:
        - lib/**
        - test/**
  cache:
    enabled: true
    directory: .fx_cache
```

Alternatively, create a standalone `fx.yaml` file at the workspace root with the same content (without nesting under `fx:`).

## Step 2: Verify Discovery

```text
fx list
```

fx scans the `packages` glob patterns and discovers all projects with `pubspec.yaml` files. It automatically:

- Detects project types (Dart package, Flutter package, Flutter app, Dart CLI)
- Resolves path dependencies between workspace projects
- Infers targets from project structure (e.g., `test/` directory → test target)

## Step 3: Add .fxignore (Optional)

Create `.fxignore` at the workspace root to exclude directories from project discovery:

```text
# Exclude build artifacts
**/build/
**/.dart_tool/

# Exclude specific packages
packages/legacy_*
```

## Step 4: Run Tasks

```text
fx run-many --target test
fx run-many --target analyze
fx affected --target test --base main
```

## Auto-Detected Targets

fx infers targets from your project structure even without explicit configuration:

| File/Directory | Inferred Target |
|----------------|----------------|
| `test/` | `test` (dart test / flutter test) |
| `analysis_options.yaml` | `analyze` (dart analyze) |
| `lib/` | `format` (dart format .) |
| `bin/` (Dart CLI) | `compile` (dart compile exe) |
| `integration_test/` (Flutter) | `integration_test` |
| `build.yaml` | `build` (dart run build_runner build) |

## Flutter Project Routing

fx automatically routes Dart commands to Flutter equivalents for Flutter projects. If your workspace target uses `dart test`, Flutter packages will use `flutter test` instead.
