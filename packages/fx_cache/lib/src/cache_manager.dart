import 'cache_entry.dart';
import 'stores/local_cache_store.dart';
import 'stores/remote_cache_store.dart';

/// Orchestrates local and optional remote cache stores.
///
/// Read strategy (local-first):
///   1. Check local store — return immediately on hit.
///   2. Check remote store (if configured) — on hit, populate local and return.
///   3. Return null (cache miss).
///
/// Write strategy: write to local always; write to remote when configured.
class CacheManager {
  final LocalCacheStore localStore;
  final RemoteCacheStore? remoteStore;

  CacheManager({required this.localStore, this.remoteStore});

  /// Returns a cached entry for [hash], or null on cache miss.
  Future<CacheEntry?> get(String hash) async {
    // Local hit
    final local = await localStore.get(hash);
    if (local != null) return local;

    // Remote hit — populate local for next time
    if (remoteStore != null) {
      try {
        final remote = await remoteStore!.get(hash);
        if (remote != null) {
          await localStore.put(hash, remote);
          return remote;
        }
      } catch (_) {
        // Remote cache failures are best-effort; degrade gracefully
      }
    }

    return null;
  }

  /// Stores [entry] in local (and remote if configured).
  Future<void> put(String hash, CacheEntry entry) async {
    await localStore.put(hash, entry);
    try {
      await remoteStore?.put(hash, entry);
    } catch (_) {
      // Remote cache writes are best-effort
    }
  }

  /// Returns true if [hash] exists in local or remote store.
  Future<bool> has(String hash) async {
    if (await localStore.has(hash)) return true;
    if (remoteStore != null && await remoteStore!.has(hash)) return true;
    return false;
  }

  /// Clears the local cache only.
  Future<void> clearLocal() => localStore.clear();

  /// Clears both local and remote caches.
  Future<void> clearAll() async {
    await localStore.clear();
    await remoteStore?.clear();
  }
}
