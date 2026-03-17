---
title: Editor Integration
description: IDE and editor support for fx workspaces.
---

# Editor Integration

## fx Daemon

fx includes a daemon process for IDE integration:

```text
fx daemon
```

The daemon provides a persistent connection for editors to query workspace state, project graph, and task status without cold-starting fx on every operation.

## Shell Completion

fx supports shell tab completion via `cli_completion`. Enable it for your shell:

```text
fx completion
```

This outputs a completion script you can source in your `.bashrc`, `.zshrc`, or equivalent.

## Graph Visualization

Use the interactive web graph viewer:

```text
fx graph --web --port 4211
```

This starts a local server with a visual, interactive project dependency graph.
