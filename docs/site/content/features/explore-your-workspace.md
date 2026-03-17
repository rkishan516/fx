---
title: Explore Your Workspace
description: Understand your workspace structure through project graphs, task graphs, and interactive visualizations.
---

# Explore Your Workspace

fx organizes your workspace as a collection of **projects**. Each project has executable **targets**. Projects maintain dependencies that form the **Project Graph** — a DAG that fx uses for intelligent decisions about task execution, caching, and affected analysis.

Beyond the project graph, fx computes a **Task Graph** — a separate graph of tasks and their dependencies that determines execution order.

Understanding these graphs is **vital** to understanding both your workspace and how fx behaves.

## Exploring Projects

Projects are the building blocks of your workspace. Discover them with:

```text
$ fx list

  Package           Type            Path
  ─────────────────────────────────────────────
  shared            dart_package    packages/shared
  models            dart_package    packages/models
  utils             dart_package    packages/utils
  app               dart_cli        packages/app
  flutter_ui        flutter_app     apps/flutter_ui

  5 projects found
```

### Detailed Project View

```text
$ fx show core --targets --dependencies

  Project: core
  Type: dart_package
  Path: packages/core
  Tags: [shared, core]

  Targets:
    test     → dart test            (cached, inputs: lib/**, test/**)
    analyze  → dart analyze         (cached, inputs: lib/**)
    format   → dart format .        (cached, inputs: lib/**, test/**)
    build    → dart run build_runner build  (cached, dependsOn: [])

  Dependencies:
    (none)

  Dependents:
    models, utils, app
```

### JSON Output

```text
fx list --json
```

Returns structured data for scripting and tooling integration.

### Filter Projects

```text
fx list --type app                    # Only applications
fx list --projects "packages/*"       # Match glob patterns
```

## Exploring the Project Graph

The project graph is automatically derived from your `pubspec.yaml` path dependencies — you never have to maintain it manually. It updates as your code changes.

### Text Output

```text
$ fx graph

app
  ├── models
  │   └── shared
  └── utils
      └── shared
flutter_ui
  ├── models
  │   └── shared
  └── shared
```

### Interactive Web Visualization

```text
fx graph --web --port 4211
```

Opens a local web server with an interactive graph viewer. Use this to:

- **Understand workspace structure** at a glance
- **Trace dependency chains** between projects
- **Identify tightly coupled areas** that might need refactoring
- **Onboard new developers** by showing them the big picture

### Focus on a Specific Project

Zoom into a project and its immediate neighborhood:

```text
$ fx graph --focus core

core
  Dependents: models, utils, app, flutter_ui
  Dependencies: (none)
```

This is useful in large workspaces where the full graph is too complex to read.

### Group by Folder

Organize projects by their directory structure:

```text
fx graph --groupByFolder
```

### Export Formats

**Graphviz DOT** — Generate visual diagrams:

```text
fx graph --format dot | dot -Tpng -o graph.png
fx graph --format dot | dot -Tsvg -o graph.svg
```

**JSON** — Machine-readable data for external analysis:

```text
fx graph --format json --file graph.json
```

The JSON output includes:

```dart
{
  "nodes": ["app", "models", "shared", "utils"],
  "edges": [
    {"from": "app", "to": "models"},
    {"from": "app", "to": "shared"},
    {"from": "models", "to": "shared"},
    {"from": "utils", "to": "shared"}
  ],
  "adjacency": {
    "app": ["models", "shared"],
    "models": ["shared"],
    "shared": [],
    "utils": ["shared"]
  }
}
```

**Save to file:**

```text
fx graph --format dot --file graph.dot
```

## Exploring the Task Graph

fx determines task execution order based on the project graph and target pipelines. Preview this with `--graph`:

```text
$ fx run-many --target test --graph

Execution plan:
  1. shared:test         (no dependencies)
  2. utils:test          (no dependencies, parallel with shared)
  3. models:test         (depends on: shared:test)
  4. app:test            (depends on: models:test, utils:test)
```

This works with any execution command:

```text
fx run app test --graph          # Single project task graph
fx run-many --target build --graph   # All projects
fx affected --target test --graph    # Affected projects only
```

<Info>
Dependencies in the task graph mean that fx will wait for all dependency tasks to complete successfully before starting the dependent task. A failure in any dependency stops the dependent task.
</Info>

## Affected Graph

See which projects are impacted by your current changes:

```text
$ fx graph --affected --base main

Affected projects (2 of 8):
  shared (directly changed)
  models (depends on shared)
```

## Implicit Dependency Detection

fx can detect workspace packages that are imported in source code but not declared in `pubspec.yaml`:

```text
$ fx graph --detect-implicit

Implicit dependencies found:
  utils imports 'package:shared' but doesn't declare it in pubspec.yaml
```

This helps catch undeclared dependencies that could cause issues if `shared` changes.

## Cycle Detection

Circular dependencies make topological sort impossible. fx detects them automatically:

```text
$ fx graph

Error: Circular dependency detected:
  app → models → core → app

Fix the cycle before running tasks.
```

See [Troubleshooting: Circular Dependencies](/troubleshooting/circular-dependencies) for resolution strategies.

## Use Cases for Graph Exploration

| Scenario | Command |
|----------|---------|
| Onboard a new developer | `fx graph --web` |
| Understand a PR's impact | `fx graph --affected --base main` |
| Find undeclared dependencies | `fx graph --detect-implicit` |
| Generate architecture diagrams | `fx graph --format dot \| dot -Tpng -o arch.png` |
| Debug task ordering | `fx run-many --target build --graph` |
| Check for cycles | `fx graph` (auto-detected) |

## Learn More

- [Affected Analysis](/features/affected) — Run tasks on affected projects only
- [Enforce Module Boundaries](/features/enforce-module-boundaries) — Add rules to the graph
- [Inferred Tasks](/concepts/inferred-tasks) — How fx auto-detects targets
- [Types of Configuration](/concepts/configuration) — Where project settings come from
