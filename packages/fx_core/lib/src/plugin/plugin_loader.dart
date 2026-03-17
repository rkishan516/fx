import '../models/config_types.dart';
import '../utils/logger.dart';
import '../workspace/workspace.dart';
import 'plugin_hook.dart';

/// Factory function that creates a [PluginHook] given plugin options.
typedef PluginHookFactory = PluginHook Function(Map<String, dynamic> options);

/// Resolves and instantiates [PluginHook]s from the workspace plugin config.
///
/// Plugins are registered in the static [defaultRegistry]. In production, the
/// CLI registers all built-in and third-party plugins before startup. For
/// tests, use the injectable [registry] parameter in [fromWorkspace].
///
/// Plugins are returned sorted by [PluginConfig.priority] descending (higher
/// priority runs first), matching Nx's plugin ordering semantics.
class PluginLoader {
  /// The global plugin registry, keyed by plugin name.
  static final Map<String, PluginHookFactory> defaultRegistry = {};

  /// Resolve [PluginHook]s from [workspace] config.
  ///
  /// [registry] overrides [defaultRegistry] (useful for testing).
  ///
  /// Plugins that are not found in [registry] are logged as warnings and
  /// skipped — they do not cause the run to fail.
  static List<PluginHook> fromWorkspace(
    Workspace workspace, {
    Map<String, PluginHookFactory>? registry,
  }) {
    final reg = registry ?? defaultRegistry;
    final configs = workspace.config.pluginConfigs;
    if (configs.isEmpty) return const [];

    // Sort configs by priority descending before instantiating
    final sorted = List<PluginConfig>.from(configs)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final hooks = <PluginHook>[];
    for (final config in sorted) {
      final factory = reg[config.plugin];
      if (factory == null) {
        Logger.verbose(
          'PluginLoader: unknown plugin "${config.plugin}" — skipped.',
        );
        continue;
      }
      try {
        hooks.add(factory(config.options));
      } catch (e) {
        Logger.verbose(
          'PluginLoader: failed to load plugin "${config.plugin}": $e — skipped.',
        );
      }
    }
    return hooks;
  }
}
