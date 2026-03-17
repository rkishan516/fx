---
title: fx — Smart Monorepo Tool for Dart & Flutter
description: A powerful monorepo management tool for Dart and Flutter projects. Task orchestration, computation caching, affected analysis, code generation, and a plugin system.
---

# fx

**Smart monorepo tool for Dart & Flutter.** Manage workspaces, run tasks in topological order, cache results, generate scaffolding, and analyze affected projects — all from a single CLI.

## Why fx?

Managing multiple Dart and Flutter packages in a single repository is complex. fx gives you:

- **Speed** — Cache task results with SHA-256 input hashing. Never re-run unchanged work. Local + remote stores (S3, GCS).
- **Intelligence** — Only run tasks on projects affected by your changes. Auto-detect dependencies via import analysis.
- **Order** — Execute tasks in dependency order with parallel execution, batch grouping, and continuous task support.
- **Structure** — Enforce module boundaries and conformance rules across your workspace with built-in and custom rules.
- **Scaffolding** — Generate new packages, apps, and plugins from templates with interactive prompts.
- **CI/CD** — Auto-detect 9 CI providers. Get base ref, cache paths, and log grouping out of the box.
- **Extensibility** — Plugin system for executors, generators, inference hooks, and conformance rules.
- **AI-Native** — MCP server exposes workspace tools to AI assistants like Claude.

## Quick Example

```text
fx init --name my_monorepo
fx generate dart_package core
fx generate flutter_app mobile
fx run-many --target test
fx affected --target test --base main
fx ci-info
```

<Info>
fx dogfoods its own monorepo capabilities — the tool itself is structured as a multi-package Dart workspace with 700+ tests.
</Info>

## Feature Overview

| Feature | Description |
|---------|-------------|
| [Run Tasks](/features/run-tasks) | Execute targets across projects with dependency ordering, parallelism, and continuous tasks |
| [Cache Results](/features/cache-task-results) | SHA-256 input hashing with local and remote (S3/GCS) cache stores |
| [Affected Analysis](/features/affected) | Run tasks only on changed projects and their dependents |
| [Module Boundaries](/features/enforce-module-boundaries) | Tag-based dependency constraints with pluggable conformance rules |
| [Code Generation](/features/generate-code) | Scaffold packages, apps, and plugins from templates with interactive prompts |
| [Graph Visualization](/features/explore-your-workspace) | Dependency and task graph with DOT, JSON, web, and text output |
| [Plugin System](/concepts/plugins) | Executors, generators, inference hooks, and conformance rules |
| [Batch Execution](/features/batch-execution) | Group independent tasks sharing the same executor |
| [Watch Mode](/features/watch-mode) | Re-run targets automatically on file changes |
| [Distributed CI](/features/distribute-tasks) | Split work across CI matrix workers |
| [Release Management](/features/manage-releases) | Coordinated versioning and changelogs across packages |
| [Background Daemon](/concepts/daemon) | Persistent graph with incremental git-based change detection |
| [CI Integration](/recipes/ci-setup) | Auto-detect providers, base refs, log grouping, and cache paths |
| [MCP Server](/getting-started/editor-integration) | AI-native workspace tools via Model Context Protocol |

## Get Started

- [Introduction](/getting-started/intro) — What is fx and how does it work?
- [Installation](/getting-started/installation) — Install fx and prerequisites
- [Add to Existing Project](/getting-started/add-to-existing) — Adopt fx in your monorepo
- [Tutorial](/getting-started/tutorial) — Build a workspace from scratch
