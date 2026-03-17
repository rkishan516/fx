# Example fx Workspace

A minimal monorepo demonstrating fx capabilities.

## Structure

```
example/
  pubspec.yaml          # Workspace root with fx: config
  packages/
    shared/             # Shared utility library
    app/                # Application that depends on shared
```

## Try it

From the repository root, with `fx` installed:

```bash
# List projects
fx list --workspace example

# View dependency graph (app -> shared)
fx graph --workspace example

# Run tests across all projects in dependency order
fx run-many --target test --workspace example

# Analyze all packages
fx analyze --workspace example
```
