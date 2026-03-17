import 'migration_change.dart';

/// Abstract base class for plugin migration generators.
///
/// A migration generator handles upgrading workspace configuration when a
/// plugin version changes. It follows a two-phase workflow:
/// 1. [prepare] — dry-run, returns a list of proposed changes without applying them
/// 2. [execute] — applies the changes from the prepare phase
///
/// This is the fx equivalent of Nx's migration generator system.
abstract class MigrationGenerator {
  /// The plugin/package version this migration migrates FROM.
  String get fromVersion;

  /// The plugin/package version this migration migrates TO.
  String get toVersion;

  /// The name of the plugin this migration belongs to.
  String get pluginName;

  /// Compute the list of changes needed without applying them.
  ///
  /// [workspaceRoot] is the absolute path to the workspace root.
  /// Returns a list of [MigrationChange] objects describing what would change.
  Future<List<MigrationChange>> prepare(String workspaceRoot);

  /// Apply the [changes] returned by [prepare].
  ///
  /// [workspaceRoot] is the absolute path to the workspace root.
  Future<void> execute(String workspaceRoot, List<MigrationChange> changes);
}
