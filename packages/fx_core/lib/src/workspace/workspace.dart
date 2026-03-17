import '../models/project.dart';
import '../models/target.dart';
import '../models/workspace_config.dart';
import '../plugin/plugin_hook.dart';

/// The top-level workspace object combining config and discovered projects.
class Workspace {
  final String rootPath;
  final FxConfig config;
  final List<Project> projects;

  /// Plugin hooks loaded for this workspace.
  /// Set after workspace loading via [PluginLoader.fromWorkspace].
  List<PluginHook> pluginHooks;

  Workspace({
    required this.rootPath,
    required this.config,
    required this.projects,
    this.pluginHooks = const [],
  });

  /// Find a project by its package name.
  Project? projectByName(String name) {
    for (final project in projects) {
      if (project.name == name) return project;
    }
    return null;
  }

  /// Resolve the correct executor command for a target on a given project.
  ///
  /// Flutter projects substitute `dart` with `flutter` for common commands.
  String resolveExecutor(Project project, String targetName) {
    // Check for project-level target override first
    final projectTarget = project.targets[targetName];
    if (projectTarget != null) return projectTarget.executor;

    // Fall back to workspace-level target config
    final wsTarget = config.targets[targetName];
    if (wsTarget == null) return '';

    String executor = wsTarget.executor;

    // Route flutter CLI for flutter projects
    if (project.isFlutter) {
      executor = routeFlutterExecutor(executor);
    }

    return executor;
  }

  /// Substitute `dart` with `flutter` for Flutter-specific commands.
  static String routeFlutterExecutor(String executor) {
    const dartToFlutter = {
      'dart test': 'flutter test',
      'dart analyze': 'flutter analyze',
      'dart pub get': 'flutter pub get',
      'dart pub upgrade': 'flutter pub upgrade',
    };
    return dartToFlutter[executor] ?? executor;
  }

  /// Resolve a target with plugin-inferred cache config as lowest priority.
  ///
  /// Merge order (lowest to highest priority):
  /// 1. Plugin-inferred inputs/outputs
  /// 2. targetDefaults
  /// 3. Workspace targets
  /// 4. Project targets
  Future<Target?> resolveTargetWithPlugins(String name, Project project) async {
    final base = config.resolveTarget(
      name,
      projectTarget: project.targets[name],
    );
    if (base == null) return null;

    // If inputs/outputs already set by higher-priority config, skip plugins
    if (base.inputs.isNotEmpty && base.outputs.isNotEmpty) return base;

    // Query plugins for cache config suggestions
    for (final hook in pluginHooks) {
      final inferred = await hook.inferCacheConfig(project, base);
      if (inferred == null) continue;

      return base.copyWith(
        inputs: base.inputs.isEmpty ? inferred.inputs : null,
        outputs: base.outputs.isEmpty ? inferred.outputs : null,
      );
    }

    return base;
  }

  @override
  String toString() =>
      'Workspace(root: $rootPath, ${projects.length} projects)';
}
