---
title: Remote Cache
description: Share cached task results across your team and CI runners with remote cache stores.
---

# Remote Cache

Local caching saves time on repeated runs on the same machine. But the real power comes from **sharing** cached results across your team and CI. When one developer runs tests, the results are available to every other developer and every CI runner.

## How It Works

```text
Developer A runs tests (cache miss):
  1. Compute hash
  2. Check local → miss
  3. Check remote → miss
  4. Execute tests (3.2s)
  5. Store result locally + remotely

Developer B runs same tests (cache hit):
  1. Compute hash (same code = same hash)
  2. Check local → miss (different machine)
  3. Check remote → HIT
  4. Download result, store locally
  5. Replay output (0.05s)
```

The `CacheManager` checks stores in order:

1. **Local store** — Filesystem cache at `.fx_cache/` (fast, per-machine)
2. **Remote store** — Shared cache (network latency, shared across all machines)

On a remote hit, the entry is pulled down and stored locally for future use on that machine.

## Configuration

```yaml
fx:
  cache:
    enabled: true
    directory: .fx_cache
    remoteUrl: https://cache.example.com
```

## Built-in Remote Stores

### HTTP Remote Cache

The simplest option. Communicates with any HTTP server implementing this API:

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/cache/:hash` | Retrieve cache entry (200 with JSON body, or 404) |
| `PUT` | `/cache/:hash` | Store cache entry (JSON body) |
| `HEAD` | `/cache/:hash` | Check existence (200 or 404) |
| `DELETE` | `/cache` | Clear all entries |

```yaml
fx:
  cache:
    remoteUrl: https://cache.example.com
```

You can use any HTTP server that implements this interface — a simple Express/Shelf server with file storage works fine for small teams.

#### Authentication

```dart
final store = HttpRemoteCacheStore(
  baseUrl: 'https://cache.example.com',
  headers: {'Authorization': 'Bearer $token'},
);
```

### S3 Remote Cache

Works with AWS S3, MinIO, DigitalOcean Spaces, and any S3-compatible object store:

```dart
final store = S3RemoteCacheStore(
  bucket: 'my-fx-cache',
  region: 'us-east-1',
  prefix: 'fx-cache/',
  accessKey: Platform.environment['AWS_ACCESS_KEY_ID']!,
  secretKey: Platform.environment['AWS_SECRET_ACCESS_KEY']!,
);
```

Objects are stored at `<prefix>/<hash>.json`. S3 lifecycle rules can handle expiration automatically.

#### IAM Policy (Minimum Permissions)

```text
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject", "s3:HeadObject"],
  "Resource": "arn:aws:s3:::my-fx-cache/fx-cache/*"
}
```

### Google Cloud Storage

```dart
final store = GcsRemoteCacheStore(
  bucket: 'my-fx-cache',
  prefix: 'fx-cache/',
  serviceAccountKey: Platform.environment['GCS_KEY'],
);
```

Use GCS lifecycle rules to auto-delete entries older than a threshold.

### Filesystem Remote Cache

For shared network drives (NFS, SMB, or mounted cloud storage):

```dart
final store = FilesystemRemoteCacheStore(
  directory: '/mnt/shared/fx-cache',
);
```

This is the simplest remote store — no server needed. Just mount a shared directory and point fx at it.

## Custom Remote Store

Implement the `RemoteCacheStore` interface for custom backends:

```dart
class RedisRemoteCacheStore implements RemoteCacheStore {
  final RedisClient client;

  RedisRemoteCacheStore(this.client);

  @override
  Future<CacheEntry?> get(String hash) async {
    final data = await client.get('fx-cache:$hash');
    if (data == null) return null;
    return CacheEntry.fromJson(jsonDecode(data));
  }

  @override
  Future<void> put(String hash, CacheEntry entry) async {
    await client.set(
      'fx-cache:$hash',
      jsonEncode(entry.toJson()),
      ex: Duration(days: 30),    // Auto-expire after 30 days
    );
  }

  @override
  Future<bool> has(String hash) async {
    return await client.exists('fx-cache:$hash');
  }

  @override
  Future<void> clear() async {
    final keys = await client.keys('fx-cache:*');
    if (keys.isNotEmpty) await client.del(keys);
  }
}
```

## CI Configuration

### GitHub Actions

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
      - run: fx affected --target test --base origin/main
        env:
          FX_REMOTE_CACHE_URL: ${{ secrets.CACHE_URL }}
          FX_REMOTE_CACHE_TOKEN: ${{ secrets.CACHE_TOKEN }}
```

### GitLab CI

```yaml
test:
  script:
    - dart pub global activate --source git https://github.com/rkishan516/fx.git --git-path packages/fx_cli
    - fx affected --target test --base origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME
  variables:
    FX_REMOTE_CACHE_URL: $CACHE_URL
    FX_REMOTE_CACHE_TOKEN: $CACHE_TOKEN
```

## Read-Only Mode

In some setups, you want CI to read from the cache but not write to it (to prevent cache poisoning):

```yaml
fx:
  cache:
    remoteUrl: https://cache.example.com
    remoteReadOnly: true    # Read from remote, don't write
```

Or use environment variables:

```text
FX_REMOTE_CACHE_READ_ONLY=true fx run-many --target test
```

<Info>
Remote cache writes are best-effort. If the remote store is unavailable or a write fails, execution continues normally. Only the caching step is skipped — your tasks still run and complete.
</Info>

## Security Considerations

- **Authentication** — Always require authentication for write access to prevent cache poisoning
- **Read-only in PRs** — Consider making the cache read-only for PR builds and write-only for main branch builds
- **Expiration** — Set up automatic expiration (S3 lifecycle rules, Redis TTL) to prevent unbounded growth
- **Encryption** — Use HTTPS for HTTP stores and server-side encryption for S3/GCS

## Learn More

- [How Caching Works](/concepts/how-caching-works) — The caching pipeline
- [Cache Task Results](/features/cache-task-results) — User-facing caching guide
- [CI Setup](/recipes/ci-setup) — Complete CI configuration
