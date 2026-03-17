---
title: Environment Variables
description: Environment variables that control fx behavior, CI detection, and cache hashing.
---

# Environment Variables

fx reads several environment variables to control its behavior. Understanding them helps you configure fx correctly across different environments.

## fx-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FX_CI` | Force CI mode (disables interactive prompts, adjusts output) | Auto-detected |
| `FX_CONCURRENCY` | Override default concurrency | CPU core count |
| `FX_REMOTE_CACHE_URL` | Remote cache server URL | From config |
| `FX_REMOTE_CACHE_TOKEN` | Authentication token for remote cache | — |
| `FX_REMOTE_CACHE_READ_ONLY` | Make remote cache read-only | `false` |
| `FX_DEFAULT_BASE` | Override default base ref for affected analysis | From config |
| `FX_SKIP_CACHE` | Globally disable caching | `false` |

### Example Usage

```text
# Force 2 parallel workers and skip cache
FX_CONCURRENCY=2 FX_SKIP_CACHE=true fx run-many --target test

# CI with remote cache
FX_CI=true FX_REMOTE_CACHE_URL=https://cache.example.com fx affected --target test --base main
```

## CI Provider Detection

fx auto-detects CI environments by checking these variables (in order):

| Variable | Provider | Also Sets |
|----------|----------|-----------|
| `GITHUB_ACTIONS` | GitHub Actions | `GITHUB_SHA`, `GITHUB_REF` available |
| `GITLAB_CI` | GitLab CI | `CI_NODE_TOTAL`, `CI_NODE_INDEX` available |
| `CIRCLECI` | CircleCI | `CIRCLE_NODE_TOTAL`, `CIRCLE_NODE_INDEX` available |
| `TRAVIS` | Travis CI | — |
| `JENKINS_URL` | Jenkins | — |
| `BUILDKITE` | Buildkite | `BUILDKITE_PARALLEL_JOB_COUNT` available |
| `CODEBUILD_BUILD_ID` | AWS CodeBuild | — |
| `TF_BUILD` | Azure Pipelines | — |
| `BITBUCKET_BUILD_NUMBER` | Bitbucket Pipelines | — |
| `CI` | Generic CI flag | Used as fallback |

When CI is detected, fx automatically:
- Disables interactive prompts
- Uses `static` output style (no TUI spinners)
- Adjusts color output based on terminal capabilities

## Output Control

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable all ANSI color output (respects the [no-color.org](https://no-color.org) convention) |
| `TERM=dumb` | Disable color output (terminal doesn't support ANSI) |
| `FORCE_COLOR` | Force color output even in non-interactive terminals |

## Using Environment Variables in Cache Hashes

Include environment variable values in cache hashes so different environments produce different caches:

```yaml
fx:
  targets:
    build:
      inputs:
        - lib/**
        - env('DART_DEFINES')       # Build-time defines
        - env('BUILD_MODE')          # release/debug/profile
        - env('API_BASE_URL')        # Different per environment
        - env('FLUTTER_TARGET')      # Different entry points
```

This ensures:
- A `release` build doesn't serve cached `debug` results
- Different API URLs produce different cache entries
- Build flags that affect output are tracked

### Behavior When Variable is Unset

If an environment variable referenced by `env('VAR')` is not set, it's hashed as an empty string. This means:

- Setting a variable that was previously unset invalidates the cache
- Unsetting a variable that was previously set invalidates the cache
- Two machines with the same variable unset produce the same hash

## Runtime Environment Inspection

Programmatically access the detected environment:

```dart
import 'package:fx_core/fx_core.dart';

print(Environment.isCI);              // true/false
print(Environment.ciProvider);        // 'github_actions', 'gitlab_ci', etc.
print(Environment.useColor);          // true/false
print(Environment.isInteractive);     // true/false
print(Environment.defaultConcurrency); // CPU count or FX_CONCURRENCY
print(Environment.toJson());          // Full environment summary
```

## Learn More

- [Inputs and Named Inputs](/recipes/inputs-and-named-inputs) — Using env vars in input patterns
- [Remote Cache](/recipes/remote-cache) — Cache-related environment variables
- [CI Setup](/recipes/ci-setup) — CI-specific configuration
- [Distribute Tasks](/features/distribute-tasks) — CI provider matrix variables
