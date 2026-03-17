---
title: Distribute Tasks
description: Split work across CI matrix workers for faster pipelines using deterministic task distribution.
---

# Distribute Tasks

As your workspace grows, even with caching and affected analysis, CI pipelines can still take a long time. If you have 20 affected projects and each takes 30 seconds to test, that's 10 minutes in a serial pipeline.

fx supports distributing work across multiple CI matrix workers. Instead of one machine doing all the work, split it across 4 machines and finish in a quarter of the time.

## How It Looks

```text
# Worker 0 of 4
$ fx run-many --target test --workers 4 --worker-index 0

  Assigned to this worker (5 of 20 projects):
    ✓ shared:test     1.2s
    ✓ models:test     2.1s
    ✓ auth:test       1.8s
    ✓ payments:test   2.5s
    ✓ analytics:test  1.1s

  5/5 succeeded (8.7s)
```

Meanwhile, workers 1, 2, and 3 handle the remaining 15 projects in parallel.

## How Distribution Works

The `TaskPartitioner` assigns projects to workers using a **deterministic hash** of the project name modulo the worker count:

```text
hash("shared") % 4 = 0    →  Worker 0
hash("models") % 4 = 1    →  Worker 1
hash("auth") % 4 = 0      →  Worker 0
hash("ui") % 4 = 2        →  Worker 2
hash("app") % 4 = 3       →  Worker 3
```

This approach guarantees:

- **Every project is assigned to exactly one worker** — no duplication, no gaps
- **Deterministic** — same project always goes to the same worker across runs
- **No coordination needed** — workers don't communicate with each other
- **Stable** — adding or removing projects minimally affects distribution

## CI Configuration

### GitHub Actions

```yaml
name: CI
on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        index: [0, 1, 2, 3]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx run-many --target test --workers 4 --worker-index ${{ matrix.index }}
```

<Info>
Set `fail-fast: false` so all workers complete even if one fails. This gives you the full picture of failures across the workspace.
</Info>

### GitLab CI

GitLab's `parallel` keyword automatically sets `CI_NODE_TOTAL` and `CI_NODE_INDEX`:

```yaml
test:
  parallel: 4
  script:
    - dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
    - fx run-many --target test --workers $CI_NODE_TOTAL --worker-index $CI_NODE_INDEX
```

### Azure Pipelines

```yaml
strategy:
  parallel: 4

steps:
  - script: |
      dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      fx run-many --target test --workers $(System.TotalJobsInPhase) --worker-index $(System.JobPositionInPhase)
```

### CircleCI

```yaml
test:
  parallelism: 4
  steps:
    - run: |
        dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
        fx run-many --target test --workers $CIRCLE_NODE_TOTAL --worker-index $CIRCLE_NODE_INDEX
```

## Combining with Affected Analysis

The most powerful CI configuration combines distribution with affected analysis:

```text
$ fx affected --target test --base main --workers 4 --worker-index 0
```

This:
1. Determines which projects are affected by the PR
2. Distributes **only** affected projects across workers
3. Each worker runs its share of the affected workload

```yaml
# GitHub Actions — distributed affected tests
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        index: [0, 1, 2, 3]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
      - run: fx affected --target test --base origin/main --workers 4 --worker-index ${{ matrix.index }}
```

## Combining with Caching

Distribution and caching work together. Each worker benefits from its own cache:

```text
Worker 0:
  ✓ shared:test     replayed from cache (0.01s)
  ✓ auth:test       2.1s
  ✓ payments:test   2.5s
```

With remote caching enabled, workers share a common cache — a test cached by Worker 0 on a previous run can be replayed by Worker 0 on this run without re-execution.

## CI Detection

fx automatically detects CI environments and adjusts behavior (disabling interactive prompts, adjusting output formatting):

| Environment Variable | CI Provider |
|---------------------|-------------|
| `GITHUB_ACTIONS` | GitHub Actions |
| `GITLAB_CI` | GitLab CI |
| `CIRCLECI` | CircleCI |
| `TRAVIS` | Travis CI |
| `JENKINS_URL` | Jenkins |
| `BUILDKITE` | Buildkite |
| `CODEBUILD_BUILD_ID` | AWS CodeBuild |
| `TF_BUILD` | Azure Pipelines |
| `BITBUCKET_BUILD_NUMBER` | Bitbucket Pipelines |
| `FX_CI` | Force CI mode manually |

You can also force CI mode manually:

```text
FX_CI=true fx run-many --target test
```

## Scaling Guidance

| Workspace Size | Recommended Workers |
|---------------|-------------------|
| 1-10 projects | 1 (no distribution needed) |
| 10-30 projects | 2-4 workers |
| 30-100 projects | 4-8 workers |
| 100+ projects | 8-16 workers |

More workers means more parallelism but also more CI machine cost. Find the balance that works for your team and budget.

## Troubleshooting

### Uneven Distribution

Some workers finish much faster than others. This happens when project test times vary significantly. The hash-based distribution doesn't account for execution time — it only ensures even **count** distribution.

For more balanced distribution, consider splitting large test suites into smaller packages.

### Empty Workers

A worker receives 0 projects. This is normal when the total project count is less than the worker count, or when using `--affected` with few affected projects.

```text
Worker 3: No projects assigned to this worker. Exiting.
```

## Learn More

- [Affected Analysis](/features/affected) — Reduce what gets distributed
- [Cache Task Results](/features/cache-task-results) — Share results across workers with remote cache
- [CI Setup](/recipes/ci-setup) — Complete CI configuration examples
- [Environment Variables](/recipes/environment-variables) — CI detection and configuration
