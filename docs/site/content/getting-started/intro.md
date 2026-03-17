---
title: What is fx?
description: fx is a build system with smart caching and task orchestration for Dart/Flutter monorepos.
---

# What is fx?

![fx banner](/images/banner-dark.svg)

fx is a **build system for Dart and Flutter monorepos**. It helps teams develop faster and keep CI fast as codebases grow.

## The Challenge of Monorepos

As your Dart/Flutter workspace grows from a few packages to dozens, you'll encounter these problems:

- **Slow CI pipelines** — Running all tests across every package on every PR wastes time and compute
- **Complex task ordering** — Packages depend on each other, so you can't just run `dart test` in any order
- **Duplicate work** — Rebuilding code that hasn't changed is wasteful but hard to avoid manually
- **Architectural erosion** — Without guardrails, packages start depending on each other in unintended ways
- **Onboarding friction** — New developers struggle to understand the workspace structure and what depends on what

fx solves all of these.

## What fx Does

### 1. Cache Task Results

fx never rebuilds what hasn't changed. It hashes your source files, dependencies, and configuration, and replays cached results when inputs are identical.

```text
$ fx run core test
> Running "dart test" for core...
> All 24 tests passed (3.2s)

$ fx run core test
> core:test — replayed from cache (0.01s)
```

This works locally and across CI when using a [remote cache](/recipes/remote-cache).

### 2. Understand Your Workspace

fx builds a project graph from your `pubspec.yaml` path dependencies. This graph is the foundation for task ordering, affected analysis, and boundary enforcement.

```text
$ fx graph
app
  ├── models
  │   └── shared
  └── utils
      └── shared
```

Visualize it interactively with `fx graph --web`, export as [DOT for Graphviz](/features/explore-your-workspace), or query it as JSON.

### 3. Run Tasks Efficiently

fx runs tasks in topological order with parallel execution. It respects dependency chains, so `shared` always builds before `models`, which always builds before `app`.

```text
$ fx run-many --target test --concurrency 4
✓ shared:test    (1.2s)
✓ utils:test     (1.4s)
✓ models:test    (2.1s)
✓ app:test       (3.5s)

4 tasks completed in 4.8s (8.2s saved by parallelism)
```

### 4. Only Run What's Affected

On every PR, fx determines which projects changed and which depend on those changes. It only runs tasks on the affected subset.

```text
$ fx affected --target test --base main
> 2 of 8 projects affected
✓ shared:test    (1.2s)
✓ models:test    (2.1s)
6 projects skipped (not affected)
```

Learn more in [Affected Analysis](/features/affected).

### 5. Enforce Module Boundaries

Prevent architectural violations by declaring which project tags can depend on which others:

```yaml
fx:
  moduleBoundaries:
    - sourceTag: shared
      deniedTags: [app, feature]
```

```text
$ fx lint
✗ Module boundary violation:
  "shared" cannot depend on "app" (denied tag: app)
```

Learn more in [Enforce Module Boundaries](/features/enforce-module-boundaries).

## How fx is Built

fx is itself a Dart monorepo, structured as six focused packages:

![fx architecture](/images/architecture.svg)

| Component | Description |
|-----------|-------------|
| **fx_core** | Models, workspace loading, plugins, migrations, file utilities |
| **fx_graph** | Project graph, task graph, topological sort, cycle detection, affected analysis, conformance rules |
| **fx_runner** | Task execution engine with parallel runner, batch mode, continuous tasks, executor plugins |
| **fx_cache** | SHA-256 input hashing, local and remote cache stores (S3, GCS), graph cache |
| **fx_generator** | Code generation framework with 7 built-in generators, interactive prompts, template engine |
| **fx_cli** | 30+ CLI commands, output formatting, terminal UI, background daemon, MCP server |

## Can I Use fx Without a Monorepo?

Yes. Even single-package projects benefit from:

- **Task caching** — Skip unchanged test runs
- **Code generation** — Scaffold new packages quickly
- **Consistent tooling** — Standard commands for test, build, analyze, format

But fx shines brightest in workspaces with multiple interconnected packages.

## Next Steps

| Goal | Page |
|------|------|
| Install fx and create a workspace | [Installation](/getting-started/installation) |
| Add fx to an existing project | [Add to Existing Project](/getting-started/add-to-existing) |
| Learn by building | [Tutorial](/getting-started/tutorial) |
| Explore all features | [Features](/features/run-tasks) |
