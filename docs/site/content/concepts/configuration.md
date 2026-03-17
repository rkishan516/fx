---
title: Types of Configuration
description: Complete guide to fx configuration — workspace config, project config, inheritance, named configurations, and the full schema.
---

# Types of Configuration

fx reads configuration from two sources: the `fx:` section in your root `pubspec.yaml`, or a standalone `fx.yaml` file. This page covers everything you can configure.

## Configuration Sources

### pubspec.yaml

```yaml
# Root pubspec.yaml
name: my_workspace
fx:
  packages:
    - packages/*
  targets:
    test:
      executor: dart test
```

### fx.yaml

```yaml
# fx.yaml (no fx: prefix needed)
packages:
  - packages/*
targets:
  test:
    executor: dart test
```

Both are equivalent. If both exist, `fx.yaml` takes precedence.

## Configuration Inheritance

Extend a base config to share settings across multiple workspaces or environments:

```yaml
# fx.yaml
extendsConfig: base-config.yaml

targets:
  test:
    executor: dart test --coverage   # Override the base
```

The `_mergeWithBase()` method deep-merges configurations. The extending file's values take priority over the base:

- Maps are merged recursively (both base and extending keys are preserved)
- Lists are replaced entirely (not concatenated)
- Scalar values from the extending config override the base

### Multi-Level Inheritance

```yaml
# base.yaml
cache:
  enabled: true
  maxSize: 500

# team.yaml
extendsConfig: base.yaml
moduleBoundaries:
  - sourceTag: shared
    deniedTags: [app]

# fx.yaml
extendsConfig: team.yaml
targets:
  test:
    executor: dart test
```

## Full Configuration Schema

```yaml
fx:
  # ─── Project Discovery ───────────────────────────────
  packages:
    - packages/*           # Glob patterns for package directories
    - apps/*
    - "!packages/legacy"   # Exclude patterns

  # ─── Target Definitions ──────────────────────────────
  targets:
    test:
      executor: dart test
      inputs:
        - lib/**
        - test/**
      outputs:
        - coverage/
      dependsOn:
        - build
        - ^build
      cache: true
      options:
        batchable: true
        coverage: true

    build:
      executor: dart run build_runner build
      inputs:
        - lib/**
        - build.yaml
      outputs:
        - lib/**/*.g.dart

    analyze:
      executor: dart analyze
      inputs:
        - lib/**
        - analysis_options.yaml

  # ─── Target Defaults (lowest priority) ───────────────
  targetDefaults:
    test:
      inputs: [lib/**, test/**]
      cache: true
    build:
      inputs: [lib/**]
      cache: true

  # ─── Named Input Sets ───────────────────────────────
  namedInputs:
    default:
      - lib/**
      - pubspec.yaml
    testing:
      - "{default}"
      - test/**
    building:
      - "{default}"
      - build.yaml

  # ─── Module Boundaries ──────────────────────────────
  moduleBoundaries:
    - sourceTag: app
      allowedTags: [feature, shared]
    - sourceTag: feature
      allowedTags: [shared, core]
      deniedTags: [feature]
    - sourceTag: shared
      deniedTags: [app, feature]

  # ─── Conformance Rules ──────────────────────────────
  conformanceRules:
    - id: require-test-target
      type: require-target
      options:
        target: test
    - id: no-wildcard-deps
      type: no-wildcard-dependencies

  # ─── Cache Settings ─────────────────────────────────
  cache:
    enabled: true
    directory: .fx_cache
    maxSize: 500             # MB
    remoteUrl: https://cache.example.com

  # ─── Global Settings ────────────────────────────────
  defaultBase: main          # Default base ref for affected analysis
  parallel: 4                # Default concurrency
  skipCache: false           # Globally disable caching
  captureStderr: false       # Include stderr in cache
  dynamicDependencies: false # Enable import-based dep detection

  # ─── Generators ─────────────────────────────────────
  generators:
    - tools/generators
  generatorDefaults:
    dart_package:
      description: "A workspace package"
      sdkConstraint: "^3.5.0"

  # ─── Sync Generators ────────────────────────────────
  syncConfig:
    applyChanges: true
    disabledGenerators:
      - legacy_generator

  # ─── Named Configurations ──────────────────────────
  configurations:
    production:
      skipCache: true
      targets:
        build:
          executor: dart run build_runner build --release
    development:
      parallel: 1

  # ─── Release Coordination ──────────────────────────
  releaseConfig:
    projectsRelationship: fixed
    releaseTagPattern: "v{version}"
    changelog:
      projectChangelogs: true
      workspaceChangelog: true
    git:
      commit: true
      commitMessage: "chore(release): v{version}"
      tag: true
    groups:
      core:
        projects: [fx_core, fx_graph]
        projectsRelationship: fixed

  # ─── Root-Level Scripts ─────────────────────────────
  scripts:
    check: "fx run-many --target test && fx run-many --target analyze"
    ci: "fx affected --target test --base origin/main --bail"
    format-all: "fx run-many --target format"

  # ─── Plugin Scoping ────────────────────────────────
  pluginConfigs:
    - plugin: tools/plugins/flutter_only
      include: ["packages/flutter_*"]
      exclude: ["packages/flutter_legacy"]

  # ─── Terminal UI ────────────────────────────────────
  tuiConfig:
    enabled: true
    autoExit: 5              # Seconds to wait before auto-closing
```

## Per-Project Configuration

Individual projects add an `fx:` section to their own `pubspec.yaml`:

```yaml
# packages/core/pubspec.yaml
name: core
fx:
  tags:
    - shared
    - core
  targets:
    test:
      executor: dart test --coverage
      inputs:
        - lib/**
        - test/**
        - fixtures/**
      dependsOn:
        - build
```

### What Can Be Configured Per-Project

| Setting | Per-Project? | Description |
|---------|-------------|-------------|
| `tags` | Yes | Project categorization for module boundaries |
| `targets` | Yes | Override workspace targets for this project |
| `type` | Yes | Override auto-detected project type |
| Other settings | No | Workspace-level only |

Project-level targets completely replace the workspace-level target for that project — they don't merge.

## Named Configurations

Switch between configurations at runtime:

```text
$ fx run core test --configuration production
```

Named configurations are merged on top of the base config:

```yaml
fx:
  configurations:
    ci:
      skipCache: true
      parallel: 8
    coverage:
      targets:
        test:
          executor: dart test --coverage
```

This is useful for:
- CI vs. local development settings
- Debug vs. release builds
- Coverage runs vs. normal test runs

## Configuration Validation

fx validates configuration at startup and reports errors:

```text
$ fx run-many --target test

  Error: Invalid configuration in fx.yaml:
    - targets.test.dependsOn[0]: Unknown target "bild" (did you mean "build"?)
    - moduleBoundaries[0].sourceTag: Empty string not allowed
    - cache.maxSize: Must be a positive integer
```

## Learn More

- [Workspace Configuration](/reference/workspace-configuration) — Full reference for all settings
- [Project Configuration](/reference/project-configuration) — Per-project settings
- [Mental Model](/concepts/mental-model) — How configuration fits into the architecture
