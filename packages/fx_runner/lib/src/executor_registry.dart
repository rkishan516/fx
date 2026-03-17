import 'executor_plugin.dart';

/// Prefix that identifies a plugin executor in target config.
///
/// Example: `executor: plugin:coverage` resolves to the `coverage` plugin.
const pluginExecutorPrefix = 'plugin:';

/// Registry of executor plugins.
///
/// Resolves executor strings: plain strings use the default process executor,
/// `plugin:<name>` strings resolve to a registered [ExecutorPlugin].
class ExecutorRegistry {
  final Map<String, ExecutorPlugin> _plugins = {};

  ExecutorRegistry();

  /// Register an executor plugin. Overwrites any existing plugin with the
  /// same [ExecutorPlugin.name].
  void register(ExecutorPlugin plugin) {
    _plugins[plugin.name] = plugin;
  }

  /// Returns the plugin for [name], or null if not registered.
  ExecutorPlugin? get(String name) => _plugins[name];

  /// All registered plugin names.
  List<String> get names => List.unmodifiable(_plugins.keys);

  /// Whether [executor] string references a plugin (starts with `plugin:`).
  static bool isPluginExecutor(String executor) =>
      executor.startsWith(pluginExecutorPrefix);

  /// Extract the plugin name from a `plugin:<name>` executor string.
  static String extractPluginName(String executor) =>
      executor.substring(pluginExecutorPrefix.length);
}
