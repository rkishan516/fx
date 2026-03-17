---
title: Project Configuration
description: Per-project configuration in pubspec.yaml.
---

# Project Configuration

Individual projects can add an `fx:` section to their own `pubspec.yaml` to override workspace-level settings.

## Schema

```yaml
# packages/my_package/pubspec.yaml
name: my_package
version: 1.0.0

dependencies:
  shared:
    path: ../shared

fx:
  tags:                            # Project categorization
    - shared
    - core
  targets:
    <target-name>:
      executor: <command>          # Override workspace executor
      inputs: [<patterns>]
      outputs: [<patterns>]
      dependsOn: [<targets>]
      cache: true
      options: {}
```

## Tags

Tags categorize projects for module boundary enforcement and conformance rules:

```yaml
fx:
  tags:
    - shared
    - utility
    - team-platform
```

Tags support wildcard matching in module boundary rules (`feature-*` matches `feature-auth`, `feature-payments`).

## Target Overrides

Project targets take the highest priority in target resolution:

1. **targetDefaults** — lowest
2. **targets** (workspace) — middle
3. **Project fx.targets** — highest

```yaml
# Workspace: dart test
# This project: dart test --coverage --concurrency=1
fx:
  targets:
    test:
      executor: dart test --coverage --concurrency=1
      inputs:
        - lib/**
        - test/**
        - fixtures/**
```

## Project Type Detection

fx auto-detects the project type from its structure:

| Type | Detection |
|------|-----------|
| `dartPackage` | Default for Dart packages |
| `flutterPackage` | Has `flutter` dependency, no `lib/main.dart` |
| `flutterApp` | Has `flutter` dependency and `lib/main.dart` |
| `dartCli` | Has `bin/` directory |

The detected type affects executor routing (Dart → Flutter) and target inference.

## Dependencies

Dependencies are discovered from `pubspec.yaml` path dependencies:

```yaml
dependencies:
  shared:
    path: ../shared
  models:
    path: ../models
```

Only path dependencies within the workspace are tracked in the project graph. External pub dependencies are not graph edges.

## hasBuildRunner

fx auto-detects if a project depends on `build_runner`. If so, it infers a `build` target:

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.0.0
```

This automatically adds `dart run build_runner build` as an inferred target.
