---
title: Root-Level Scripts
description: Define and run workspace-level scripts for CI workflows, multi-step commands, and custom tooling.
---

# Root-Level Scripts

Most fx commands run targets on projects. But sometimes you need workspace-level commands that aren't tied to any specific project — CI pipelines, cleanup tasks, multi-step workflows.

Root-level scripts fill this gap.

## Configuration

```yaml
fx:
  scripts:
    check: "fx run-many --target test && fx run-many --target analyze"
    ci: "fx affected --target test --base origin/main --bail"
    deploy: "./scripts/deploy.sh"
    clean: "fx cache clear && rm -rf build/"
    format-all: "fx run-many --target format"
    bootstrap: "dart pub get && fx sync"
```

## Running Scripts

Use the `:` prefix to distinguish root-level scripts from project targets:

```text
$ fx run :check

  Running script "check"...
  > fx run-many --target test && fx run-many --target analyze

  ✓ shared:test     1.2s
  ✓ utils:test      1.4s
  ✓ models:test     2.1s
  ✓ app:test        3.5s
  ✓ shared:analyze  0.5s
  ✓ utils:analyze   0.4s
  ✓ models:analyze  0.6s
  ✓ app:analyze     0.7s

  Script "check" completed successfully.
```

## Common Script Patterns

### CI Pipeline

```yaml
fx:
  scripts:
    ci:verify: "fx affected --target test --base origin/main --bail && fx lint"
    ci:build: "fx run-many --target build --skip-cache"
    ci:deploy: "fx run-many --target build && ./scripts/deploy.sh"
```

```text
$ fx run :ci:verify    # Run in CI
```

### Development Workflow

```yaml
fx:
  scripts:
    dev: "fx watch --target test --projects packages/core"
    dev:all: "fx watch --target test"
    reset: "fx cache clear && dart pub get"
    update-deps: "dart pub upgrade && fx sync"
```

### Code Quality

```yaml
fx:
  scripts:
    check: "fx run-many --target test && fx lint && fx run-many --target format"
    pre-commit: "fx affected --target test --base HEAD~1 && fx lint"
```

### Release

```yaml
fx:
  scripts:
    release:check: "fx run-many --target test --bail && fx lint"
    release:do: "fx release"
    release:all: "fx run :release:check && fx run :release:do"
```

## Shell Features

Scripts are executed via the system shell, so you can use standard shell features:

```yaml
fx:
  scripts:
    # Chain commands (stop on failure)
    check: "fx test && fx lint"

    # Chain commands (continue on failure)
    report: "fx test; fx lint; echo done"

    # Pipes
    graph-svg: "fx graph --format dot | dot -Tsvg -o graph.svg"

    # Environment variables
    ci: "FX_CI=true fx affected --target test --base origin/main"
```

<Info>
Root-level scripts are **not cached** — they always execute when called. Individual targets within a script (via `fx run` or `fx run-many`) are still cached per their target configuration.
</Info>

## Learn More

- [Run Tasks](/features/run-tasks) — Running targets on projects
- [CLI Commands](/reference/commands) — Full command reference
- [CI Setup](/recipes/ci-setup) — Using scripts in CI
