---
title: Installation
description: Install fx and set up your first workspace.
---

# Installation

## Prerequisites

fx requires **Dart SDK ^3.11.1**. Install it from [dart.dev]({{links.dart_sdk}}).

Verify your installation:

```text
dart --version
# Dart SDK version: 3.11.1 or higher
```

## Install fx

From GitHub:

```text
dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
```

From source (for development):

```text
git clone {{links.repo}}
cd fx
dart pub get
dart pub global activate --source path packages/fx_cli
```

Verify the installation:

```text
fx --version
```

## Create a New Workspace

```text
fx init --name my_monorepo
```

This creates:

- Root `pubspec.yaml` with the `fx:` configuration section and `workspace:` member list
- `packages/` directory for your projects
- `apps/` directory for applications
- `analysis_options.yaml` with recommended lints
- `.gitignore` with fx-specific entries

### Workspace Templates

```text
fx init --name my_monorepo --template blank    # Minimal workspace
fx init --name my_monorepo --template example  # Workspace with sample packages
```

## Add Your First Package

```text
fx generate dart_package core
```

This scaffolds `packages/core/` with `lib/`, `test/`, `pubspec.yaml`, and `analysis_options.yaml`, and adds it to the workspace member list.

## Verify Setup

```text
fx list          # List discovered projects
fx graph         # View dependency graph
fx bootstrap     # Install all dependencies
fx run-many --target test   # Run tests across all projects
```
