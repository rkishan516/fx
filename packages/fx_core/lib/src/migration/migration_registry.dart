import 'migration_generator.dart';

/// Registry of migration generators keyed by plugin name and version range.
///
/// Plugins register their migrations here. The CLI `fx migrate` command
/// queries the registry to find applicable migrations for a given version
/// transition.
class MigrationRegistry {
  final _migrations = <MigrationGenerator>[];

  /// Register a migration generator.
  void register(MigrationGenerator migration) {
    _migrations.add(migration);
  }

  /// Find all migrations for [pluginName] that apply between
  /// [currentVersion] and [targetVersion].
  ///
  /// Returns migrations sorted by [fromVersion] so they can be applied in order.
  /// A migration applies if its [fromVersion] is >= [currentVersion] and
  /// its [toVersion] is <= [targetVersion].
  List<MigrationGenerator> findMigrations({
    required String pluginName,
    required String currentVersion,
    required String targetVersion,
  }) {
    final applicable = _migrations.where((m) {
      if (m.pluginName != pluginName) return false;
      return _versionInRange(m.fromVersion, currentVersion, targetVersion) &&
          _versionInRange(m.toVersion, currentVersion, targetVersion);
    }).toList();

    applicable.sort((a, b) => _compareVersions(a.fromVersion, b.fromVersion));
    return applicable;
  }

  /// Returns all registered migrations.
  List<MigrationGenerator> get all => List.unmodifiable(_migrations);

  /// Check if [version] falls within [minVersion] (inclusive) and [maxVersion] (inclusive).
  static bool _versionInRange(
    String version,
    String minVersion,
    String maxVersion,
  ) {
    return _compareVersions(version, minVersion) >= 0 &&
        _compareVersions(version, maxVersion) <= 0;
  }

  /// Compare two semver-like version strings.
  /// Returns negative if a < b, 0 if equal, positive if a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).toList();
    final bParts = b.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final aVal = (i < aParts.length ? aParts[i] : null) ?? 0;
      final bVal = (i < bParts.length ? bParts[i] : null) ?? 0;
      if (aVal != bVal) return aVal - bVal;
    }
    return 0;
  }
}
