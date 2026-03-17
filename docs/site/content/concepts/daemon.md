---
title: fx Daemon
description: The fx daemon process for IDE integration, persistent workspace state, and faster repeated commands.
---

# fx Daemon

Every time you run an fx command, it needs to parse your configuration, discover projects, build the project graph, and resolve targets. For large workspaces, this startup cost adds up — especially when running commands repeatedly during development.

The fx daemon is a persistent background process that keeps this state in memory, making subsequent commands near-instant.

## Starting the Daemon

```text
$ fx daemon

  fx daemon started on port 4200
  Workspace: /path/to/workspace
  Projects: 24
  Graph edges: 47

  Watching for configuration changes...
```

The daemon runs in the background and serves requests from fx CLI commands. When a command detects a running daemon, it delegates workspace queries to the daemon instead of computing them from scratch.

## Performance Impact

| Operation | Without Daemon | With Daemon |
|-----------|---------------|------------|
| Parse configuration | ~200ms | 0ms (cached) |
| Discover projects | ~300ms | 0ms (cached) |
| Build project graph | ~100ms | 0ms (cached) |
| Resolve targets | ~50ms | 0ms (cached) |
| **Total startup overhead** | **~650ms** | **~5ms** |

For a single command, 650ms is barely noticeable. But during active development — when you're running `fx run core test` dozens of times — those milliseconds add up to minutes.

## What the Daemon Caches

| State | Behavior |
|-------|----------|
| Workspace configuration | Loaded once, reloaded on `fx.yaml` or `pubspec.yaml` changes |
| Project list | Computed once, recomputed when directories change |
| Project graph | Built once, rebuilt when dependencies change |
| Target resolution | Cached per-project, invalidated on config changes |
| Cache index | Loaded once, updated as tasks run |

The daemon watches your workspace for file changes and automatically invalidates the relevant cached state. You don't need to restart it when you modify configuration.

## When to Use the Daemon

### Use It For

- **Active development** — Running fx commands repeatedly
- **IDE integration** — IDE plugins that need workspace state
- **Large workspaces** — Where startup overhead is noticeable (50+ packages)
- **Graph visualization** — `fx graph --web` uses the daemon to serve the interactive viewer

### Skip It For

- **CI/CD pipelines** — Each command runs independently; daemon adds complexity
- **One-off commands** — Single `fx affected` run doesn't benefit from caching
- **Small workspaces** — Startup overhead is negligible with < 10 packages

## Stopping the Daemon

```text
$ fx daemon --stop

  fx daemon stopped.
```

Or simply terminate the process. The daemon writes no persistent state — stopping it has no side effects.

## Daemon Status

```text
$ fx daemon --status

  fx daemon is running
  PID: 12345
  Port: 4200
  Uptime: 2h 34m
  Projects: 24
  Cache state: current (last reload: 12s ago)
```

## Learn More

- [Editor Integration](/getting-started/editor-integration) — How IDE plugins use the daemon
- [Explore Your Workspace](/features/explore-your-workspace) — Graph visualization powered by the daemon
