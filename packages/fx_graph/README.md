# fx_graph

Project dependency graph analysis for the fx monorepo tool.

## Overview

Builds a directed acyclic graph (DAG) from workspace project dependencies, detects cycles, performs topological sorting, and identifies affected projects from git changes.

## Key Classes

| Class | Description |
|-------|-------------|
| `ProjectGraph` | DAG of project dependencies with adjacency list representation |
| `TopologicalSorter` | Kahn's algorithm for dependency-ordered execution |
| `CycleDetector` | Detects circular dependencies in the project graph |
| `AffectedAnalyzer` | Determines which projects are affected by file changes (git diff + transitive dependents) |
| `GraphOutput` | Renders graph as text, JSON, or DOT format |

## Usage

```dart
import 'package:fx_graph/fx_graph.dart';

final graph = ProjectGraph.fromProjects(projects);

// Topological order
final sorted = TopologicalSorter(graph).sort();

// Cycle detection
final cycles = CycleDetector(graph).findCycles();

// Affected analysis
final affected = await AffectedAnalyzer(graph, workspaceRoot: root)
    .analyze(base: 'main');
```
