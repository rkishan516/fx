---
title: Mental Model
description: Core concepts behind fx's design and how the pieces fit together to manage your workspace.
---

# Mental Model

Before diving into individual features, it helps to understand the five core concepts that fx is built around. Every feature — caching, affected analysis, task pipelines, module boundaries — connects back to these fundamentals.

## 1. The Project Graph

At the heart of fx is a **directed acyclic graph (DAG)** of your workspace projects. Each node is a package; each edge is a `pubspec.yaml` path dependency.

```text
app
  ├── models
  │   └── shared
  └── utils
      └── shared
```

fx builds this graph automatically by scanning your workspace for packages and reading their `pubspec.yaml` dependencies. You never maintain it manually.

This graph is the foundation for **everything**:

| Feature | How It Uses the Graph |
|---------|----------------------|
| Task ordering | Tasks run in topological order — dependencies before dependents |
| Affected analysis | Changes propagate forward through the graph to dependents |
| Module boundaries | Dependency rules are enforced against graph edges |
| Cache invalidation | A project's hash includes its transitive dependency hashes |
| Batch execution | Only independent projects (no graph edges between them) can batch |

The graph is computed once at startup and cached by the daemon for repeated use. View it anytime with `fx graph`.

## 2. Targets and Executors

A **target** is a named task you can run on a project — like `test`, `build`, or `analyze`. An **executor** is the command that implements the target.

```yaml
fx:
  targets:
    test:
      executor: dart test      # The executor
      inputs:                  # Files that affect the cache hash
        - lib/**
        - test/**
      cache: true              # Enable caching
```

Targets come from three sources, merged in priority order:

| Priority | Source | Example |
|----------|--------|---------|
| Lowest | **Inferred** from project structure | `test/` directory → `test` target |
| Middle | **Workspace** config (root `pubspec.yaml` or `fx.yaml`) | Explicit target definitions |
| Highest | **Project** config (project's `pubspec.yaml`) | Per-project overrides |

Higher-priority sources override lower ones. This means you can define workspace-wide defaults and override them for specific projects that need different behavior.

## 3. Input Hashing

fx identifies "what changed" by computing a **SHA-256 hash** of all inputs to a task. If the hash matches a previous run, the cached result is replayed instead of re-executing.

The hash includes:

| Component | Why It Matters |
|-----------|---------------|
| Matching source files | Code changes invalidate the cache |
| Executor command | Different commands produce different results |
| Dart SDK version | SDK updates can change behavior |
| `pubspec.lock` content | Dependency version changes affect output |
| Environment variables | When configured with `env('VAR')` |
| Runtime command output | When configured with `runtime('cmd')` |

Files are **sorted by path** before hashing to ensure deterministic results across operating systems and file system orderings.

The key insight: **if the hash is the same, the output is the same**. This is what makes caching safe — as long as your tasks are side-effect free, replaying a cached result is indistinguishable from running the task again.

## 4. Task Pipelines

Targets can declare dependencies on other targets via `dependsOn`. This creates a **task pipeline** — an ordered sequence of targets that must execute before the requested target.

```yaml
fx:
  targets:
    test:
      dependsOn:
        - build        # Run build before test on THIS project
        - ^build       # Run build on all DEPENDENCY projects first
```

The `^` prefix is crucial. It means "run this target on all dependency projects in the graph first." Given `app → models → shared`:

Running `fx run app test` with the config above executes:

1. `build` on `shared` (dependency of models)
2. `build` on `models` (dependency of app)
3. `build` on `app` (same project)
4. `test` on `app` (the requested target)

Without `^`, only step 3 and 4 would run — the dependency projects wouldn't build first.

## 5. Workspace Configuration

fx is configured through a single source — the `fx:` section in your root `pubspec.yaml` or a standalone `fx.yaml` file. This config defines everything:

```yaml
fx:
  packages:              # Where to find projects
    - packages/*
    - apps/*
  targets:               # What tasks can run
    test: { ... }
  cache:                 # How results are cached
    enabled: true
  moduleBoundaries:      # Architectural constraints
    - { ... }
  releaseConfig:         # Release coordination
    { ... }
```

Configuration cascades from workspace level to project level, with projects able to override any workspace setting. See [Types of Configuration](/concepts/configuration) for the complete schema.

## How the Pieces Fit Together

When you run `fx run-many --target test`:

1. **Project Graph** — fx loads the graph and determines which projects have the `test` target
2. **Task Pipeline** — For each project, fx resolves `dependsOn` to build the full task list
3. **Topological Sort** — Tasks are ordered so dependencies execute before dependents
4. **Input Hashing** — Before each task, fx computes the hash and checks the cache
5. **Execution** — Cache misses are executed; cache hits are replayed
6. **Storage** — New results are stored in the cache for future runs

This pipeline runs with maximum parallelism — independent tasks execute concurrently while respecting dependency order.

## Learn More

- [How Caching Works](/concepts/how-caching-works) — Deep dive into the caching pipeline
- [Task Pipeline Configuration](/concepts/task-pipeline-configuration) — Configure `dependsOn` chains
- [Inferred Tasks](/concepts/inferred-tasks) — How fx auto-detects targets
- [Types of Configuration](/concepts/configuration) — Full configuration reference
