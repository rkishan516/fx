---
title: Tutorial
description: Build a Dart monorepo workspace from scratch with fx.
---

# Tutorial: Build a Workspace

This tutorial walks through creating a workspace with multiple packages, running tasks, and using fx's key features.

## 1. Create the Workspace

```text
fx init --name my_app
cd my_app
```

## 2. Generate Packages

```text
fx generate dart_package shared
fx generate dart_package models
fx generate dart_cli app
```

Your workspace now has three packages:

```text
packages/
  shared/      # Utility package
  models/      # Data models
  app/         # CLI application
```

## 3. Add Dependencies

Make `models` depend on `shared`, and `app` depend on both:

```text
fx import --source shared --target models
fx import --source shared --target app
fx import --source models --target app
```

## 4. View the Graph

```text
fx graph
```

Output:

```text
app
  ├── models
  │   └── shared
  └── shared
```

## 5. Run Tasks

```text
# Run tests in dependency order
fx run-many --target test

# Run tests on a single project
fx run shared test

# Run with parallelism
fx run-many --target test --concurrency 4
```

## 6. Use Caching

Run the same command again:

```text
fx run-many --target test
```

The second run replays cached results — no actual test execution needed.

Check the cache:

```text
fx cache status
```

## 7. Affected Analysis

Make a change to `packages/shared/lib/shared.dart`, then:

```text
fx affected --target test --base HEAD
```

This runs tests on `shared`, `models`, and `app` — because they all transitively depend on `shared`.

## 8. Analyze and Format

```text
fx analyze           # Run dart analyze on all packages
fx format            # Run dart format on all packages
```

## 9. Configure Targets

Customize targets in your root `pubspec.yaml`:

```yaml
fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
      inputs:
        - lib/**
        - test/**
        - pubspec.yaml
      dependsOn:
        - build
    build:
      executor: dart run build_runner build
      inputs:
        - lib/**
        - build.yaml
      cache: true
  cache:
    enabled: true
    directory: .fx_cache
```

Now `fx run-many --target test` will automatically run `build` before `test` for each project.

## 10. Enforce Architecture

Add module boundary rules:

```yaml
fx:
  moduleBoundaries:
    - sourceTag: app
      allowedTags:
        - models
        - shared
    - sourceTag: models
      allowedTags:
        - shared
    - sourceTag: shared
      deniedTags:
        - app
        - models
```

Tag your projects in their `pubspec.yaml`:

```yaml
fx:
  tags:
    - shared
```

Then lint:

```text
fx lint
```
