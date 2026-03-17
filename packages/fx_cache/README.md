# fx_cache

Computation caching for the fx monorepo tool.

## Overview

Skips re-running unchanged tasks by hashing inputs (source files, dependencies, config) with SHA-256 and storing results locally. Supports pluggable remote cache stores.

## Key Classes

| Class | Description |
|-------|-------------|
| `CacheManager` | Main cache API — check, store, and retrieve cached task results |
| `Hasher` | SHA-256 input hashing (`hashInputs` combines file contents, dependency hashes, and config) |
| `CacheEntry` | Metadata for a cached result (hash, timestamp, duration) |
| `LocalCacheStore` | File-system-based cache storage |
| `RemoteCacheStore` | Interface for remote cache backends |
| `FilesystemRemoteCacheStore` | Reference implementation of `RemoteCacheStore` using a shared directory |

## Usage

```dart
import 'package:fx_cache/fx_cache.dart';

final cache = CacheManager(cacheDir: '.fx_cache');

final hash = await Hasher.hashInputs(projectPath: 'packages/core', target: 'test');
final entry = await cache.get(hash);
if (entry != null) {
  print('Cache hit! Skipping task.');
} else {
  // Run task, then store result
  await cache.put(hash, CacheEntry(...));
}
```
