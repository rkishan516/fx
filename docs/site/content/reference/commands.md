---
title: CLI Commands
description: Complete reference for all fx CLI commands, options, and usage examples.
---

# CLI Commands

This page documents every fx command, its options, and common usage patterns.

## Project Management

### `fx init`

Initialize a new fx workspace.

```text
fx init --name <name> [--dir <dir>] [--template <template>]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--name`, `-n` | Workspace name (required) | — |
| `--dir`, `-d` | Target directory | Current directory |
| `--template`, `-t` | Template: `blank` or `example` | `blank` |

```text
$ fx init --name my_workspace --template example
  Created workspace "my_workspace" with example packages
```

### `fx generate`

Scaffold a new project from a generator.

```text
fx generate <generator> <name> [options]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--directory`, `-d` | Output directory | `packages/<name>` |
| `--dry-run` | Preview without writing | `false` |
| `--list` | List available generators | — |
| `--interactive`, `-i` | Prompt for options | `false` |
| `--no-interactive` | Skip prompts (CI) | `false` |

Built-in generators: `dart_package`, `dart_cli`, `flutter_package`, `flutter_app`, `add_dependency`, `rename_package`, `move_package`.

```text
$ fx generate dart_package my_utils
$ fx generate flutter_app my_app --directory apps/my_app
$ fx generate --list
$ fx generate dart_package my_utils --dry-run
```

### `fx import`

Add a workspace project as a path dependency.

```text
fx import --source <source-project> --target <dependency-project>
```

```text
$ fx import --source my_app --target shared
  Added shared as dependency of my_app
```

### `fx list`

List all workspace projects.

```text
fx list [--json] [--type <type>] [--projects <patterns>]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--json` | JSON output for scripting | `false` |
| `--type` | Filter by type: `app`, `package` | All types |
| `--projects` | Glob filter patterns | All projects |

```text
$ fx list
$ fx list --json
$ fx list --type app
$ fx list --projects "packages/*"
```

### `fx show`

Show detailed project information.

```text
fx show <project> [--targets] [--dependencies]
```

```text
$ fx show core --targets --dependencies

  Project: core
  Type: dart_package
  Path: packages/core
  Tags: [shared, core]

  Targets:
    test     → dart test            (cached)
    analyze  → dart analyze         (cached)

  Dependencies: (none)
  Dependents: models, utils, app
```

## Task Execution

### `fx run`

Run a target on a single project, or a root-level script.

```text
fx run <project> <target> [options]
fx run :<script-name>
```

| Option | Description | Default |
|--------|-------------|---------|
| `--skip-cache` | Bypass cache | `false` |
| `--verbose`, `-v` | Verbose output (shows hash, file list) | `false` |
| `--configuration` | Named configuration | — |
| `--output-style` | `stream`, `static`, `tui` | `stream` |
| `--graph` | Preview execution plan without running | `false` |
| `--exclude-task-dependencies` | Skip `dependsOn` targets | `false` |

```text
$ fx run core test
$ fx run core test --skip-cache
$ fx run core test --configuration ci
$ fx run core test --graph
$ fx run :check                    # Root-level script
```

### `fx run-many`

Run a target across multiple projects with parallel execution.

```text
fx run-many --target <target> [options]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--target` | Target to run (required, repeatable) | — |
| `--projects` | Include projects (glob patterns) | All projects |
| `--exclude` | Exclude projects (glob patterns) | — |
| `--concurrency` | Parallel execution limit | CPU cores |
| `--skip-cache` | Bypass cache | `false` |
| `--bail` | Stop on first failure | `false` |
| `--graph` | Preview execution plan | `false` |
| `--output-style` | `stream`, `static`, `tui` | `static` |
| `--workers` | CI matrix: total workers | — |
| `--worker-index` | CI matrix: this worker's index (0-based) | — |
| `--verbose` | Detailed output | `false` |

```text
$ fx run-many --target test
$ fx run-many --target test --target analyze
$ fx run-many --target test --concurrency 4
$ fx run-many --target test --projects "packages/*" --bail
$ fx run-many --target test --workers 4 --worker-index 0
```

### `fx affected`

Run a target only on projects affected by git changes.

```text
fx affected --target <target> [options]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--target` | Target to run (required) | — |
| `--base` | Base git ref for comparison | From config (`defaultBase`) |
| `--head` | Head git ref | `HEAD` |
| `--files` | Explicit comma-separated file list | — |
| `--uncommitted` | Include uncommitted changes | `false` |
| `--untracked` | Include untracked files | `false` |
| `--exclude` | Exclude projects (glob) | — |
| `--parallel` | Concurrency limit | CPU cores |
| `--output-style` | Output format | `static` |
| `--graph` | Preview affected graph | `false` |
| `--bail` | Stop on first failure | `false` |
| `--skip-cache` | Bypass cache | `false` |
| `--workers` | CI matrix: total workers | — |
| `--worker-index` | CI matrix: this worker's index | — |
| `--verbose` | Show file-to-project mapping | `false` |

```text
$ fx affected --target test --base main
$ fx affected --target test --base HEAD~5
$ fx affected --target test --base main --bail
$ fx affected --target test --base main --uncommitted --untracked
$ fx affected --target test --base main --workers 4 --worker-index 0
```

### `fx exec`

Run an arbitrary shell command across all project directories.

```text
fx exec <command> [--projects <patterns>] [--exclude <patterns>]
```

```text
$ fx exec "dart pub get"
$ fx exec "rm -rf build/" --projects "packages/*"
```

### `fx watch`

Watch file system and re-run targets on changes.

```text
fx watch --target <target> [--projects <patterns>] [--output-style <style>]
```

```text
$ fx watch --target test
$ fx watch --target test --projects "packages/core"
$ fx watch --target test --target analyze
```

## Code Quality

### `fx analyze`

Run `dart analyze` across all (or selected) packages.

```text
fx analyze [--exclude <patterns>]
```

### `fx format`

Run `dart format .` across all (or selected) packages.

```text
fx format [--exclude <patterns>]
```

### `fx lint`

Evaluate conformance rules and module boundaries.

```text
fx lint [--rules <rules>] [--verbose]
```

```text
$ fx lint
$ fx lint --rules "require-target,naming-convention"
$ fx lint --verbose
```

## Graph and Visualization

### `fx graph`

Output the project dependency graph.

```text
fx graph [options]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--format` | Output format: `text`, `json`, `dot` | `text` |
| `--web` | Launch interactive web visualization | `false` |
| `--port` | Web server port | `4211` |
| `--focus` | Zoom into a project's neighborhood | — |
| `--affected` | Filter to affected projects | `false` |
| `--base` | Base ref for affected filter | From config |
| `--groupByFolder` | Group by directory structure | `false` |
| `--detect-implicit` | Find undeclared imports | `false` |
| `--file` | Save output to file | — |

```text
$ fx graph
$ fx graph --web --port 4211
$ fx graph --format dot | dot -Tpng -o graph.png
$ fx graph --format json --file graph.json
$ fx graph --focus core
$ fx graph --affected --base main
$ fx graph --detect-implicit
```

## Cache Management

### `fx cache status`

Show cache statistics.

```text
$ fx cache status
  Cache location: .fx_cache/
  Entries: 42
  Total size: 12.3 MB
```

### `fx cache clear`

Remove all cached results.

```text
$ fx cache clear
  Cleared 42 cache entries
```

## Workspace Operations

### `fx bootstrap`

Run `dart pub get` for the workspace.

```text
fx bootstrap
```

### `fx sync`

Run workspace sync generators.

```text
fx sync
```

### `fx check:sync`

Check if sync generators would produce changes (CI mode — exits non-zero if changes needed).

```text
fx check:sync
```

### `fx repair`

Auto-fix common workspace issues (missing pubspec fields, broken path dependencies).

```text
fx repair
```

### `fx reset`

Reset workspace to clean state.

```text
fx reset
```

### `fx migrate`

Migrate workspace configuration between fx versions.

```text
fx migrate [--from <version>] [--to <version>]
```

## Release Management

### `fx release`

Coordinate versioning, changelog generation, and git tagging.

```text
fx release [options]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--version` | Version or bump type (`major`, `minor`, `patch`, or semver) | Auto-detect from commits |
| `--from` | Starting tag for changelog | Auto-detect |
| `--dry-run` | Preview without modifying files | `false` |
| `--group` | Release specific group only | All groups |
| `--preid` | Pre-release identifier (`beta`, `rc`) | — |

```text
$ fx release
$ fx release --version minor
$ fx release --version 2.0.0
$ fx release --dry-run
$ fx release --group core-packages
```

## Advanced

### `fx daemon`

Start the persistent background daemon for IDE integration.

```text
fx daemon [--stop] [--status]
```

### `fx report`

Generate a workspace analysis report.

```text
fx report [--format <format>]
```

### `fx mcp`

Model Context Protocol server management for AI integration.

```text
fx mcp [--install] [--list]
```

### `fx plugin`

Manage workspace plugins.

### `fx add`

Add a workspace generator plugin.

### `fx configure-ai-agents`

Set up AI integration for the workspace.

## Global Flags

These flags work with all commands:

| Flag | Description |
|------|-------------|
| `--help`, `-h` | Show help for a command |
| `--version` | Show fx version |
| `--verbose`, `-v` | Enable verbose output |
