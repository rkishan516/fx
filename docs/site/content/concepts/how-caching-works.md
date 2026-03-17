---
title: How Caching Works
description: Deep dive into fx's computation caching pipeline — from input hashing to cache lookup to output restoration.
---

# How Caching Works

fx's caching system is the core performance feature. Understanding how it works helps you configure it correctly and debug cache issues.

The system has four stages: **hash**, **lookup**, **execute**, **store**.

## Stage 1: Input Hashing

Before running a target, the `Hasher` computes a SHA-256 hash from all relevant inputs:

```text
SHA-256(
  target_name +
  executor_command +
  dart_sdk_version +
  sorted(file_path + file_content for each matching file) +
  pubspec.lock_content +
  env_variable_values +
  runtime_command_outputs
)
```

### File Collection

Files are collected by expanding the target's `inputs` patterns:

```yaml
inputs:
  - lib/**          # All files in lib/
  - test/**         # All files in test/
  - pubspec.yaml    # The pubspec itself
  - "!**/*.md"      # Exclude markdown files
```

Files are **sorted by path** before hashing to ensure determinism across different file systems and operating systems. This means the same set of files always produces the same hash, regardless of the order in which the OS returns directory listings.

### Special Input Patterns

| Pattern | Resolved To | Use Case |
|---------|-------------|----------|
| `env('DART_DEFINES')` | Value of the environment variable | Build-time config that affects output |
| `runtime('dart --version')` | Output of running the command | SDK version tracking |
| `{externalDependencies}` | Contents of `pubspec.lock` | Dependency version changes |
| `{projectRoot}/lib/**` | Glob relative to project root | Explicit root-relative paths |
| `{workspaceRoot}/config/**` | Glob relative to workspace root | Shared workspace-level config |

### Named Inputs

Define reusable input pattern sets to avoid duplication across targets:

```yaml
fx:
  namedInputs:
    default:
      - lib/**
      - pubspec.yaml
    testing:
      - "{default}"      # Expands to lib/**, pubspec.yaml
      - test/**
    building:
      - "{default}"
      - build.yaml
  targets:
    test:
      inputs:
        - "{testing}"    # Expands to lib/**, pubspec.yaml, test/**
    build:
      inputs:
        - "{building}"
```

Named inputs can reference other named inputs, creating composable sets. Circular references are detected and reported as errors.

## Stage 2: Cache Lookup

The `CacheManager` checks for a cached result in order:

```text
1. Local store    →  .fx_cache/<hash>.json
   ├── Hit?  →  Return cached result
   └── Miss? →  Continue to remote

2. Remote store   →  https://cache.example.com/<hash>
   ├── Hit?  →  Download, save to local, return cached result
   └── Miss? →  No cache available

3. No cache found →  Proceed to execution
```

The two-tier lookup means:
- **Local hits** are instant (filesystem read)
- **Remote hits** have network latency but save execution time
- **Cache misses** proceed to normal execution

### Cache Key

The cache key is the SHA-256 hash computed in Stage 1. This means identical inputs always produce the same cache key, regardless of which machine computed it. This property is what makes remote caching work — a cache entry stored by CI can be used by a developer, and vice versa.

## Stage 3: Execute (Cache Miss)

If no cached result exists, the target is executed normally. The `TaskExecutor` runs the command and captures:

| Captured | Purpose |
|----------|---------|
| Exit code | Determine success/failure |
| Standard output | Replay terminal output on cache hit |
| Standard error | Replay error output on cache hit |
| Duration | Report timing |
| Output artifacts | Restore generated files on cache hit |

Output artifacts are files matching the target's `outputs` patterns:

```yaml
fx:
  targets:
    build:
      outputs:
        - "lib/**/*.g.dart"     # Generated code
        - "build/**"            # Build artifacts
```

## Stage 4: Store Result

After execution, the `CacheEntry` is written:

```text
1. Local store    →  Always (synchronous)
2. Remote store   →  Best-effort (async, failures don't block)
```

### Cache Entry Structure

```dart
{
  "projectName": "core",
  "targetName": "test",
  "exitCode": 0,
  "stdout": "00:01 +24: All tests passed!",
  "stderr": "",
  "duration": 3200,
  "inputHash": "a1b2c3d4e5f6...",
  "outputArtifacts": {
    "lib/src/model.g.dart": "<base64-encoded content>"
  }
}
```

Both terminal output and file artifacts are stored, so a cache hit restores the complete state — it's indistinguishable from running the task again.

## Output Artifact Restoration

When a cache hit includes output artifacts, the `OutputCollector` restores them to disk:

```text
$ fx run core build

  core:build — replayed from cache (0.02s)
  Restored 3 output files:
    lib/src/model.g.dart
    lib/src/config.g.dart
    lib/src/routes.g.dart
```

Without `outputs` configuration, only terminal output is restored. Generated files would be missing, potentially causing downstream failures. Always configure `outputs` for targets that produce files needed by other tasks.

## LRU Eviction

When `maxSize` is configured, the `LocalCacheStore` tracks total cache size. When it exceeds the limit, entries are evicted in LRU order (oldest last-modified time first):

```yaml
fx:
  cache:
    maxSize: 500    # MB
```

```text
$ fx cache status

  Cache location: .fx_cache/
  Entries: 142
  Total size: 487 MB / 500 MB
  Oldest entry: 2026-02-15 (core:test)
  Newest entry: 2026-03-16 (app:build)
```

Eviction happens lazily — before storing a new entry, fx checks the total size and removes old entries until under the limit.

## Cache Validity

A cached result is valid as long as its input hash matches. There is no time-based expiration. This means:

- A 3-month-old cache entry is still valid if nothing changed
- A 1-second-old cache entry is invalid if any input changed
- Upgrading the Dart SDK invalidates all entries (SDK version is in the hash)
- Changing `pubspec.lock` invalidates entries (lock file is in the hash)

## What Makes a Task Cacheable

For caching to be correct, a task must be **deterministic** — given the same inputs, it always produces the same outputs. Tasks that meet this criteria:

| Cacheable | Not Cacheable |
|-----------|--------------|
| `dart test` | `./scripts/deploy.sh` |
| `dart analyze` | API calls to external services |
| `dart format .` | Tasks that read system time |
| `dart run build_runner build` | Tasks that send notifications |

Mark non-deterministic tasks with `cache: false`:

```yaml
fx:
  targets:
    deploy:
      executor: ./scripts/deploy.sh
      cache: false
```

## Learn More

- [Cache Task Results](/features/cache-task-results) — User-facing caching guide
- [Inputs and Named Inputs](/recipes/inputs-and-named-inputs) — Advanced input configuration
- [Remote Cache](/recipes/remote-cache) — Share cache across machines
