import '../cache_entry.dart';

/// Abstract interface for cache storage backends.
abstract class CacheStore {
  /// Retrieve a cached entry by its input hash. Returns null if not found.
  Future<CacheEntry?> get(String hash);

  /// Store an entry keyed by its input hash.
  Future<void> put(String hash, CacheEntry entry);

  /// Returns true if an entry exists for the given hash.
  Future<bool> has(String hash);

  /// Remove all cached entries.
  Future<void> clear();
}
