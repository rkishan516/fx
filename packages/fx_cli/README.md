# fx_cli

CLI entry point for the fx monorepo tool.

## Overview

Provides the `fx` command-line interface with 11 commands for managing Dart/Flutter monorepo workspaces. Built on the `args` package with shell completion support via `cli_completion`.

## Commands

| Command | Description |
|---------|-------------|
| `fx init` | Initialize a new workspace |
| `fx generate` | Scaffold a new project from a generator |
| `fx list` | List all projects (supports `--json`) |
| `fx graph` | Output dependency graph (text, JSON, DOT) |
| `fx run` | Run a target on a specific project |
| `fx run-many` | Run a target across multiple projects |
| `fx affected` | Run a target on projects affected by git changes |
| `fx format` | Format all Dart files |
| `fx analyze` | Analyze all packages |
| `fx bootstrap` | Run `dart pub get` at workspace root |
| `fx cache` | Manage computation cache (status, clear) |

## Key Classes

| Class | Description |
|-------|-------------|
| `FxCommandRunner` | Main command runner; extends `CompletionCommandRunner` with injectable `processRunner`, `outputSink`, `cacheDir` |
| `OutputFormatter` | Formats output as text tables, JSON, or DOT graph notation |

## Usage

```dart
import 'package:fx_cli/fx_cli.dart';

final runner = FxCommandRunner();
await runner.run(['list', '--json']);
```
