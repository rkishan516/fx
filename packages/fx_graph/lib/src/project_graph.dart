import 'package:fx_core/fx_core.dart';

/// A directed acyclic graph (DAG) of project dependencies.
///
/// Maintains both forward (dependencies) and reverse (dependents) adjacency lists.
class ProjectGraph {
  final Map<String, Set<String>> _dependencies;
  final Map<String, Set<String>> _dependents;
  final Set<String> _implicitEdges;

  const ProjectGraph._({
    required Map<String, Set<String>> dependencies,
    required Map<String, Set<String>> dependents,
    Set<String> implicitEdges = const {},
  }) : _dependencies = dependencies,
       _dependents = dependents,
       _implicitEdges = implicitEdges;

  /// Build a graph from a list of [projects].
  factory ProjectGraph.build(List<Project> projects) {
    final dependencies = <String, Set<String>>{};
    final dependents = <String, Set<String>>{};

    // Initialize all nodes
    for (final project in projects) {
      dependencies[project.name] = {};
      dependents[project.name] = {};
    }

    // Add edges
    for (final project in projects) {
      for (final dep in project.dependencies) {
        dependencies[project.name]!.add(dep);
        // Ensure dep node exists (might not be in workspace)
        dependents.putIfAbsent(dep, () => {});
        dependencies.putIfAbsent(dep, () => {});
        dependents[dep]!.add(project.name);
      }
    }

    return ProjectGraph._(dependencies: dependencies, dependents: dependents);
  }

  /// All node names in the graph.
  Set<String> get nodes => _dependencies.keys.toSet();

  /// Direct dependencies of [name].
  Set<String> dependenciesOf(String name) =>
      Set.unmodifiable(_dependencies[name] ?? {});

  /// Direct dependents of [name] (projects that depend on [name]).
  Set<String> dependentsOf(String name) =>
      Set.unmodifiable(_dependents[name] ?? {});

  /// All transitively dependent projects (projects that depend on [name], recursively).
  Set<String> transitiveDependentsOf(String name) {
    final visited = <String>{};
    final queue = [...dependentsOf(name)];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (visited.contains(current)) continue;
      visited.add(current);
      queue.addAll(dependentsOf(current));
    }
    return visited;
  }

  /// Whether the graph contains [name].
  bool contains(String name) => _dependencies.containsKey(name);

  /// Whether the edge from [source] to [target] is implicit (detected via
  /// import analysis rather than pubspec.yaml).
  bool isImplicit(String source, String target) =>
      _implicitEdges.contains('$source->$target');

  /// All implicit edges as `{source: [targets]}`.
  Map<String, List<String>> get implicitEdges {
    final result = <String, List<String>>{};
    for (final edge in _implicitEdges) {
      final parts = edge.split('->');
      result.putIfAbsent(parts[0], () => []).add(parts[1]);
    }
    return result;
  }

  /// Build a graph with edges contributed by [hooks] (plugin dependency inference).
  ///
  /// Each hook's [PluginHook.inferDependencies] is called and the returned
  /// edges are merged in. Edges that already exist from pubspec.yaml are not
  /// duplicated.
  static Future<ProjectGraph> buildWithPlugins(
    List<Project> projects, {
    List<PluginHook> hooks = const [],
  }) async {
    // Start with the standard build
    final base = ProjectGraph.build(projects);
    if (hooks.isEmpty) return base;

    // Collect plugin-contributed edges
    final extraDeps = <String, Set<String>>{};
    for (final hook in hooks) {
      final contributed = await hook.inferDependencies(projects);
      for (final entry in contributed.entries) {
        extraDeps.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
    }

    if (extraDeps.isEmpty) return base;

    // Merge extra deps — re-use buildWithImplicit logic by converting to
    // the implicit deps format (only non-duplicate edges)
    final implicitDeps = <String, List<String>>{};
    for (final entry in extraDeps.entries) {
      final source = entry.key;
      final existing = base.dependenciesOf(source);
      final newEdges = entry.value.where((t) => !existing.contains(t)).toList();
      if (newEdges.isNotEmpty) {
        implicitDeps[source] = newEdges;
      }
    }

    return ProjectGraph.buildWithImplicit(projects, implicitDeps);
  }

  /// Build a graph with additional implicit dependencies from import analysis.
  ///
  /// [implicitDeps] maps project name to list of workspace projects imported
  /// but not declared in pubspec.yaml.
  factory ProjectGraph.buildWithImplicit(
    List<Project> projects,
    Map<String, List<String>> implicitDeps,
  ) {
    final dependencies = <String, Set<String>>{};
    final dependents = <String, Set<String>>{};
    final implicitEdges = <String>{};

    // Initialize all nodes
    for (final project in projects) {
      dependencies[project.name] = {};
      dependents[project.name] = {};
    }

    // Add declared edges
    for (final project in projects) {
      for (final dep in project.dependencies) {
        dependencies[project.name]!.add(dep);
        dependents.putIfAbsent(dep, () => {});
        dependencies.putIfAbsent(dep, () => {});
        dependents[dep]!.add(project.name);
      }
    }

    // Add implicit edges
    for (final entry in implicitDeps.entries) {
      final source = entry.key;
      if (!dependencies.containsKey(source)) continue;

      for (final target in entry.value) {
        if (!dependencies.containsKey(target)) continue;
        if (dependencies[source]!.contains(target)) {
          continue; // already declared
        }

        dependencies[source]!.add(target);
        dependents[target]!.add(source);
        implicitEdges.add('$source->$target');
      }
    }

    return ProjectGraph._(
      dependencies: dependencies,
      dependents: dependents,
      implicitEdges: implicitEdges,
    );
  }
}
