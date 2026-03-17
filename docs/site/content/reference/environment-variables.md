---
title: Environment Variables Reference
description: Complete reference for all environment variables that affect fx behavior.
---

# Environment Variables Reference

## fx-Specific

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `FX_CI` | bool | Force CI mode | Auto-detected |
| `FX_CONCURRENCY` | int | Override default concurrency | CPU count |
| `FX_REMOTE_CACHE_URL` | string | Remote cache server URL | From config |
| `FX_REMOTE_CACHE_TOKEN` | string | Auth token for remote cache | — |
| `FX_REMOTE_CACHE_READ_ONLY` | bool | Make remote cache read-only | `false` |
| `FX_DEFAULT_BASE` | string | Override default base ref | From config |
| `FX_SKIP_CACHE` | bool | Globally disable caching | `false` |

## CI Provider Detection

fx checks these variables to auto-detect CI environments:

| Variable | Provider |
|----------|----------|
| `GITHUB_ACTIONS` | GitHub Actions |
| `GITLAB_CI` | GitLab CI |
| `CIRCLECI` | CircleCI |
| `TRAVIS` | Travis CI |
| `JENKINS_URL` | Jenkins |
| `BUILDKITE` | Buildkite |
| `CODEBUILD_BUILD_ID` | AWS CodeBuild |
| `TF_BUILD` | Azure Pipelines |
| `BITBUCKET_BUILD_NUMBER` | Bitbucket Pipelines |
| `CI` | Generic CI flag (fallback) |

## Output Control

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable all ANSI color codes |
| `FORCE_COLOR` | Force color output in non-interactive terminals |
| `TERM` | Set to `dumb` to disable colors |

## CI Mode Effects

When fx detects a CI environment:

- Interactive prompts are disabled
- Output style defaults to `static` (no TUI spinners)
- Color output depends on terminal capabilities
- `Environment.isInteractive` returns `false`
- Generator prompts use default values

## Using in Cache Hashes

```yaml
fx:
  targets:
    build:
      inputs:
        - lib/**
        - env('DART_DEFINES')
        - env('BUILD_MODE')
```

See [Environment Variables recipe](/recipes/environment-variables) for detailed usage.
