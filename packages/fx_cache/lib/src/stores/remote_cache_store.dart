import 'cache_store.dart';

/// Abstract base class for remote cache backends.
///
/// Implementations may communicate with HTTP servers, S3-compatible storage,
/// or any other remote persistence mechanism.
abstract class RemoteCacheStore implements CacheStore {}
