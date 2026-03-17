---
title: Workspace Configuration
description: Complete reference for all fx workspace configuration options.
---

# Workspace Configuration

fx reads configuration from the `fx:` section in your root `pubspec.yaml` or from a standalone `fx.yaml` file.

## Complete Schema

```yaml
fx:
  # ── Project Discovery ──────────────────────────
  packages:                        # Glob patterns for finding projects
    - packages/*
    - apps/*

  # ── Targets ────────────────────────────────────
  targets:
    <target-name>:
      executor: <command>          # Shell command or plugin:<name>
      inputs: [<patterns>]         # Files affecting cache hash
      outputs: [<patterns>]        # Generated files to cache
      dependsOn: [<targets>]       # Prerequisite targets
      cache: true                  # Whether to cache this target
      continuous: false            # Long-running task (dev servers)
      parallelism: true            # Allow concurrent execution
      options: {}                  # Arbitrary options for executor
      configurations:              # Named config presets
        production:
          minify: true
        development:
          sourceMaps: true
      defaultConfiguration: null   # Auto-selected preset name

  targetDefaults:                  # Lowest priority target definitions
    <target-name>:
      inputs: [<patterns>]

  # ── Named Inputs ───────────────────────────────
  namedInputs:
    <name>: [<patterns>]           # Reusable input pattern sets

  # ── Module Boundaries ──────────────────────────
  moduleBoundaries:
    - sourceTag: <tag>             # Exact, glob (scope:*), regex (/pattern/)
      allowedTags: [<tags>]        # Can only depend on these
      deniedTags: [<tags>]         # Cannot depend on these

  # ── Conformance Rules ─────────────────────────
  conformanceRules:
    - id: <rule-id>
      type: <handler-type>
      options: {}

  # ── Cache ──────────────────────────────────────
  cache:
    enabled: true
    directory: .fx_cache
    maxSize: 500                   # MB, triggers LRU eviction
    remoteUrl: <url>               # Remote cache endpoint

  # ── Global Settings ────────────────────────────
  defaultBase: main                # Default git ref for affected
  parallel: 4                      # Default concurrency
  skipCache: false                 # Disable all caching
  captureStderr: false             # Cache stderr separately
  dynamicDependencies: false       # Import-based dep detection
  lockfileAffectsAll: all          # all | none — lock file change behavior

  # ── Generators ─────────────────────────────────
  generators:                      # Paths to custom generators
    - tools/generators
  generatorDefaults:               # Default values for generator prompts
    <generator>: {}

  # ── Sync ───────────────────────────────────────
  syncConfig:
    applyChanges: true
    disabledGenerators: []

  # ── Configurations ─────────────────────────────
  configurations:                  # Named config overrides
    <name>: {}

  # ── Release ────────────────────────────────────
  releaseConfig:
    projectsRelationship: fixed    # fixed | independent
    releaseTagPattern: "v{version}"
    updateDependents: auto         # always | auto | never
    changelog: {}
    git:
      commit: true
      tag: true
    groups:
      <group-name>:
        projects: [<names>]
        projectsRelationship: fixed

  # ── Scripts ────────────────────────────────────
  scripts:
    <name>: <command>              # Root-level scripts

  # ── Plugins ────────────────────────────────────
  pluginConfigs:
    - plugin: <path>
      include: [<patterns>]        # Glob patterns for project scoping
      exclude: [<patterns>]        # Glob patterns to exclude projects
      options: {}                  # Plugin-specific options
      capabilities: [inference]    # inference, dependencies, executors, generators, migrations
      priority: 0                  # Higher runs first

  # ── Terminal UI ────────────────────────────────
  tuiConfig:
    enabled: true
    autoExit: 5                    # Seconds or bool

  # ── Inheritance ────────────────────────────────
  extendsConfig: <path>            # Base config to extend
```

## Target Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `executor` | String | — | Command to execute |
| `inputs` | List\<String\> | `[]` | Glob patterns for cache hashing |
| `outputs` | List\<String\> | `[]` | Generated file patterns |
| `dependsOn` | List\<String\> | `[]` | Prerequisite targets |
| `cache` | bool | `true` | Whether results are cached |
| `continuous` | bool | `false` | Long-running task (not awaited) |
| `parallelism` | bool | `true` | Allow concurrent execution with other tasks |
| `options` | Map | `{}` | Arbitrary options for executor |
| `configurations` | Map | `{}` | Named config presets (e.g., production) |
| `defaultConfiguration` | String? | — | Auto-selected configuration name |

### Configurations

Targets can define named configuration presets that override `options`:

```yaml
targets:
  build:
    executor: dart compile
    options:
      optimize: false
    configurations:
      production:
        optimize: true
        minify: true
      development:
        sourceMaps: true
    defaultConfiguration: development
```

Use `--configuration production` (or `-c production`) with `fx run`, `fx run-many`, or `fx affected` to select a preset. Options are merged: base options + configuration overrides + CLI arguments.

### Path Tokens

Input and output patterns support these tokens:

| Token | Resolves to |
|-------|-------------|
| `{projectRoot}` | Absolute path to the project directory |
| `{workspaceRoot}` | Absolute path to the workspace root |
| `{projectName}` | The project's package name |

### Module Boundary Tag Patterns

Tags in `sourceTag`, `allowedTags`, and `deniedTags` support:

| Pattern | Example | Matches |
|---------|---------|---------|
| Exact | `scope:core` | Only `scope:core` |
| Wildcard all | `*` | Any project |
| Glob | `scope:*` | `scope:core`, `scope:shared`, etc. |
| Regex | `/^type:(lib\|util)$/` | `type:lib`, `type:util` |

## Cache Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `true` | Enable/disable caching |
| `directory` | String | `.fx_cache` | Cache storage path |
| `maxSize` | int? | — | Max size in MB (LRU eviction) |
| `remoteUrl` | String? | — | Remote cache endpoint |

## Release Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `projectsRelationship` | String | `fixed` | `fixed` (shared version) or `independent` |
| `releaseTagPattern` | String | `v{version}` | Git tag pattern (`{projectName}`, `{version}`) |
| `updateDependents` | String | `auto` | `always`, `auto`, or `never` |
| `changelog` | Map | `{}` | Changelog generation options |
| `git` | Map | `{}` | Git commit/tag/push options |
| `groups` | Map | `{}` | Named release groups |

### updateDependents

Controls how dependent packages are updated when a dependency is version-bumped:

- **`always`**: Update all dependent package constraints and patch-bump them
- **`auto`** (default): Update constraint only if the new version would break it (e.g., major version change with caret constraint)
- **`never`**: Don't touch dependent packages

## Global Settings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `defaultBase` | String | `main` | Default git ref for `fx affected` |
| `parallel` | int? | CPU count | Default task concurrency |
| `skipCache` | bool | `false` | Globally disable caching |
| `captureStderr` | bool | `false` | Cache stderr output separately |
| `dynamicDependencies` | bool | `false` | Enable import-based dependency detection |
| `lockfileAffectsAll` | String | `all` | `all`: lock file changes affect all projects; `none`: ignore lock file changes |

## Plugin Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `plugin` | String | — | Plugin package path or name |
| `include` | List\<String\> | `[]` | Glob patterns — only matching projects use this plugin |
| `exclude` | List\<String\> | `[]` | Glob patterns — exclude matching projects |
| `options` | Map | `{}` | Plugin-specific options |
| `capabilities` | List | `[]` | `inference`, `dependencies`, `executors`, `generators`, `migrations` |
| `priority` | int | `0` | Higher priority plugins run first |
