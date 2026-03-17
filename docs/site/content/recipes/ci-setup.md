---
title: CI Setup
description: Configure fx for continuous integration pipelines with caching, affected analysis, and distributed execution.
---

# CI Setup

fx is designed for CI. It auto-detects CI providers, supports distributed execution, and integrates with caching for fast pipelines. This page shows complete CI configurations for popular providers.

## GitHub Actions

### Basic Setup

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0    # Full history for affected analysis

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: "3.11.1"

      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx bootstrap

      - run: fx affected --target test --base origin/main --bail

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx bootstrap
      - run: fx lint
      - run: fx affected --target analyze --base origin/main
```

### Distributed Testing

Split work across matrix workers for larger workspaces:

```yaml
name: CI
on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        worker: [0, 1, 2, 3]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx bootstrap
      - run: fx affected --target test --base origin/main --workers 4 --worker-index ${{ matrix.worker }} --bail
```

### With Remote Cache

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx bootstrap
      - run: fx affected --target test --base origin/main
        env:
          FX_REMOTE_CACHE_URL: ${{ secrets.FX_CACHE_URL }}
          FX_REMOTE_CACHE_TOKEN: ${{ secrets.FX_CACHE_TOKEN }}
```

### Full Pipeline

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli && fx bootstrap
      - run: fx lint
      - run: fx check:sync

  test:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      fail-fast: false
      matrix:
        worker: [0, 1, 2, 3]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli && fx bootstrap
      - run: fx affected --target test --base origin/main --workers 4 --worker-index ${{ matrix.worker }} --bail
        env:
          FX_REMOTE_CACHE_URL: ${{ secrets.FX_CACHE_URL }}
          FX_REMOTE_CACHE_TOKEN: ${{ secrets.FX_CACHE_TOKEN }}

  build:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli && fx bootstrap
      - run: fx run-many --target build
```

## GitLab CI

```yaml
stages:
  - lint
  - test
  - build

variables:
  FX_REMOTE_CACHE_URL: $CACHE_URL
  FX_REMOTE_CACHE_TOKEN: $CACHE_TOKEN

.fx-setup: &fx-setup
  image: dart:3.11.1
  before_script:
    - dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
    - export PATH="$PATH:$HOME/.pub-cache/bin"
    - fx bootstrap

lint:
  <<: *fx-setup
  stage: lint
  script:
    - fx lint
    - fx check:sync

test:
  <<: *fx-setup
  stage: test
  parallel: 4
  script:
    - fx affected --target test --base origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME --workers $CI_NODE_TOTAL --worker-index $CI_NODE_INDEX --bail

build:
  <<: *fx-setup
  stage: build
  script:
    - fx run-many --target build
  only:
    - main
```

## Key CI Flags

| Flag | Purpose | When to Use |
|------|---------|-------------|
| `--bail` | Stop on first failure | Always in CI — fail fast |
| `--skip-cache` | Force fresh execution | Debugging cache issues |
| `--workers N` | Total matrix workers | Distributed execution |
| `--worker-index I` | This worker's index (0-based) | Distributed execution |
| `--output-style static` | Clean output for CI logs | Auto-set in CI mode |
| `--verbose` | Detailed output | Debugging CI issues |
| `--base origin/main` | Git base ref for affected | Always specify in CI |

## Fetch Depth

For `fx affected` to work correctly, CI needs access to git history:

```yaml
# GitHub Actions
- uses: actions/checkout@v4
  with:
    fetch-depth: 0    # Full history
```

```yaml
# GitLab CI — full history by default
variables:
  GIT_DEPTH: 0
```

Without full history, `git diff` can't compute changes since the base ref, and fx may fall back to running all projects.

<Info>
If full history checkout is too slow for large repositories, you can use a shallow clone with enough depth to reach the merge base: `fetch-depth: 100` often works. But `0` is safest.
</Info>

## CI Detection

fx automatically detects CI mode and adjusts:

| Behavior | Local | CI |
|----------|-------|----|
| Interactive prompts | Enabled | Disabled |
| Output style | `tui` or `stream` | `static` |
| Color output | Auto-detect | Auto-detect (respects `NO_COLOR`) |

Force CI mode manually:

```text
FX_CI=true fx run-many --target test
```

## Tips

1. **Always use `--bail` in CI** — Fail fast to save CI minutes
2. **Always use `fetch-depth: 0`** — Accurate affected analysis requires git history
3. **Use remote caching** — Dramatically reduces CI time across PRs
4. **Run `fx lint` first** — Catch structural issues before spending time on tests
5. **Use `fx check:sync`** — Verify generated code is committed

## Learn More

- [Affected Analysis](/features/affected) — Run only what changed
- [Distribute Tasks](/features/distribute-tasks) — Split work across workers
- [Remote Cache](/recipes/remote-cache) — Share cache across CI runs
- [Environment Variables](/recipes/environment-variables) — CI environment configuration
