# fx_runner

Task execution engine for the fx monorepo tool.

## Overview

Executes tasks (build, test, lint, etc.) across workspace projects with parallel execution, topological ordering, and failure handling.

## Key Classes

| Class | Description |
|-------|-------------|
| `TaskRunner` | Orchestrates task execution across projects with configurable concurrency and topological ordering |
| `TaskExecutor` | Executes a single task as a subprocess |
| `TaskPipeline` | Defines task dependency chains (e.g., build before test) |
| `TaskResult` | Result of a task execution (success, failure, cached, skipped) |
| `ProcessRunner` / `MockProcessRunner` | Abstraction over `Process.run` for testability |

## Usage

```dart
import 'package:fx_runner/fx_runner.dart';

final runner = TaskRunner(
  processRunner: ProcessRunner(),
  concurrency: 4,
);

final results = await runner.run(
  projects: projects,
  target: 'test',
  topologicalOrder: sortedProjects,
);
```
