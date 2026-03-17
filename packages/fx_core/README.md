# fx_core

Core models, configuration loading, and utilities for the fx monorepo tool.

## Overview

This package provides the foundation used by all other fx packages:

- **Models** — `WorkspaceConfig`, `FxConfig`, `Project`, `Target`
- **Workspace loading** — `WorkspaceLoader`, `ProjectDiscovery` for parsing `pubspec.yaml` and discovering projects
- **Utilities** — `FxException` hierarchy, `PubspecParser`, `Logger`, file helpers (`findWorkspaceRoot`, `ensureDir`, etc.)

## Key Classes

| Class | Description |
|-------|-------------|
| `WorkspaceConfig` | Parsed workspace configuration from root `pubspec.yaml` |
| `Project` | Represents a single project (name, path, dependencies, targets) |
| `Target` | A named task target with command and optional arguments |
| `WorkspaceLoader` | Loads and validates workspace configuration from disk |
| `ProjectDiscovery` | Discovers projects by scanning `packages/` for `pubspec.yaml` files |
| `FxException` | Base exception; subclasses: `WorkspaceNotFoundException`, `ConfigException` |

## Usage

```dart
import 'package:fx_core/fx_core.dart';

final workspace = await WorkspaceLoader().load('/path/to/workspace');
for (final project in workspace.projects) {
  print('${project.name}: ${project.path}');
}
```
