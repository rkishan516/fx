---
title: Adopting fx
description: Strategies for incrementally adopting fx in existing Dart/Flutter projects, including migration from Melos and manual scripts.
---

# Adopting fx

fx can be adopted incrementally in existing projects. You don't need to restructure your codebase or adopt everything at once. Start with the features that give you the biggest win and expand from there.

## Five-Phase Adoption

### Phase 1: Project Discovery

Add the `fx:` section to your root `pubspec.yaml`:

```yaml
fx:
  packages:
    - packages/*
    - apps/*
```

Verify project discovery:

```text
$ fx list

  Package           Type            Path
  ─────────────────────────────────────────────
  shared            dart_package    packages/shared
  models            dart_package    packages/models
  app               dart_cli        packages/app
  flutter_ui        flutter_app     apps/flutter_ui

  4 projects found
```

At this point, fx automatically infers targets from your project structure. Run `fx show <project> --targets` to see what was detected.

**Time investment:** 5 minutes. **Immediate benefit:** `fx list`, `fx graph`, `fx show`.

### Phase 2: Task Execution

Replace manual scripts with fx commands:

```text
# Before: manually looping
for dir in packages/*; do (cd $dir && dart test); done

# After: fx handles ordering, parallelism, and error reporting
fx run-many --target test
```

fx runs tasks in topological order with parallelism. No configuration needed — inferred targets work automatically.

**Time investment:** Zero (inferred targets). **Immediate benefit:** Parallel execution, dependency ordering, better error reporting.

### Phase 3: Caching

Add explicit target configuration with input patterns:

```yaml
fx:
  targets:
    test:
      executor: dart test
      inputs:
        - lib/**
        - test/**
      cache: true
    analyze:
      executor: dart analyze
      inputs:
        - lib/**
      cache: true
  cache:
    enabled: true
    directory: .fx_cache
```

Add `.fx_cache/` to `.gitignore`.

**Time investment:** 10 minutes. **Immediate benefit:** Repeated runs skip unchanged projects.

### Phase 4: Affected Analysis

Replace `fx run-many` with `fx affected` in CI:

```yaml
# CI configuration
- run: fx affected --target test --base origin/main --bail
```

Configure the default base ref:

```yaml
fx:
  defaultBase: main
```

**Time investment:** 5 minutes. **Immediate benefit:** CI only tests what changed.

### Phase 5: Advanced Features

Adopt these based on your needs:

| Feature | When to Adopt |
|---------|---------------|
| Module boundaries | When you want to enforce architecture |
| Remote cache | When CI time becomes a concern |
| Conformance rules | When you want workspace-wide standards |
| Release management | When publishing multiple packages |
| Distributed execution | When CI tests take > 10 minutes |

## Migration from Melos

If you're currently using Melos, here's how fx concepts map:

| Melos | fx Equivalent | Notes |
|-------|--------------|-------|
| `melos.yaml` | `fx:` in `pubspec.yaml` or `fx.yaml` | Different config format |
| `melos bootstrap` | `fx bootstrap` | Same concept |
| `melos run test` | `fx run-many --target test` | fx adds parallelism and caching |
| `melos exec -- dart test` | `fx run-many --target test` | fx uses targets, not raw commands |
| `melos list` | `fx list` | Same output |
| `melos list --graph` | `fx graph` | fx adds visualization |
| Filters (`--scope`, `--ignore`) | `--projects`, `--exclude` | Similar patterns |
| `melos version` | `fx release` | fx adds release groups |
| — | `fx affected` | No Melos equivalent |
| — | `fx lint` (boundaries) | No Melos equivalent |
| — | Remote caching | No Melos equivalent |

### Migration Steps

1. Add `fx:` config alongside `melos.yaml` (they can coexist)
2. Verify `fx list` matches `melos list`
3. Test `fx run-many --target test` produces same results
4. Migrate CI from `melos run` to `fx affected`
5. Remove `melos.yaml` when confident

## Migration from Manual Scripts

Replace shell scripts that loop over packages:

```text
# Before: shell script
#!/bin/bash
set -e
for dir in packages/*; do
  echo "Testing $dir..."
  (cd "$dir" && dart test)
done

# After: one command
fx run-many --target test
```

Benefits of the migration:
- **Dependency ordering** — fx knows which packages depend on which
- **Parallelism** — Independent packages run simultaneously
- **Caching** — Unchanged packages are skipped
- **Error reporting** — Clear summary of what passed and failed
- **Affected analysis** — Only test what changed

## Gradual Configuration

Start with inferred targets and add explicit configuration as needed:

1. **No config** — fx infers targets from project structure
2. **Workspace targets** — Add when you need caching, custom executors, or pipelines
3. **Per-project overrides** — Add when specific projects need different behavior
4. **Named inputs** — Add when multiple targets share patterns
5. **Module boundaries** — Add when you want architectural enforcement

See [Inferred Tasks](/concepts/inferred-tasks) for what fx detects automatically.

## Learn More

- [Installation](/getting-started/installation) — Install fx
- [Add to Existing Project](/getting-started/add-to-existing) — Quick start guide
- [Tutorial](/getting-started/tutorial) — Learn by building
- [Inferred Tasks](/concepts/inferred-tasks) — Auto-detected targets
