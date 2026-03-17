import 'package:fx_core/fx_core.dart';

/// A single node in the task graph representing a `project:target` pair.
class TaskNode {
  /// The project this task belongs to.
  final String projectName;

  /// The target name within the project.
  final String targetName;

  /// Resolved dependency task IDs (`project:target` format).
  final List<String> dependsOn;

  const TaskNode({
    required this.projectName,
    required this.targetName,
    required this.dependsOn,
  });

  /// Unique identifier in the form `project:target`.
  String get id => '$projectName:$targetName';

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectName': projectName,
    'targetName': targetName,
    'dependsOn': dependsOn,
  };
}

/// A directed acyclic graph (DAG) at the task level.
///
/// Expands the project-level [ProjectGraph] into individual `project:target`
/// nodes, honouring both local and transitive (`^`) [Target.dependsOn] chains.
class TaskGraph {
  final List<TaskNode> nodes;

  const TaskGraph({required this.nodes});

  /// Build a [TaskGraph] from a [workspace].
  ///
  /// For each project × target pair, [Target.dependsOn] entries are resolved:
  /// - `target`         → same-project dependency `project:target`
  /// - `^target`        → dependency on `target` in every project that the
  ///                      current project depends on (according to pubspec.yaml)
  /// - `project:target` → explicit cross-project edge
  static TaskGraph fromWorkspace(Workspace workspace) {
    final projects = workspace.projects;
    final wsConfig = workspace.config;

    // Build a quick lookup: project name → dependency names (from pubspec)
    final projectDeps = <String, List<String>>{};
    for (final p in projects) {
      projectDeps[p.name] = p.dependencies;
    }

    // Collect all unique target names visible across the workspace.
    // Project-level targets shadow workspace-level targets for that project.
    final allTargetNames = <String>{...wsConfig.targets.keys};
    for (final p in projects) {
      allTargetNames.addAll(p.targets.keys);
    }

    final nodes = <TaskNode>[];

    for (final project in projects) {
      // Determine which targets apply to this project.
      final targetNames = <String>{
        ...wsConfig.targets.keys,
        ...project.targets.keys,
      };

      for (final targetName in targetNames) {
        // Project-level target overrides workspace-level.
        final target =
            project.targets[targetName] ?? wsConfig.targets[targetName];
        if (target == null) continue;

        final resolved = <String>[];

        for (final dep in target.dependsOn) {
          if (dep.startsWith('^')) {
            // Transitive: run `dep` on every project this project depends on.
            final depTargetName = dep.substring(1);
            for (final depProjectName in projectDeps[project.name] ?? []) {
              resolved.add('$depProjectName:$depTargetName');
            }
          } else if (dep.contains(':')) {
            // Explicit project:target reference.
            resolved.add(dep);
          } else {
            // Local dependency within the same project.
            resolved.add('${project.name}:$dep');
          }
        }

        nodes.add(
          TaskNode(
            projectName: project.name,
            targetName: targetName,
            dependsOn: resolved,
          ),
        );
      }
    }

    return TaskGraph(nodes: nodes);
  }

  /// Serialise to JSON.
  ///
  /// Format:
  /// ```json
  /// {
  ///   "nodes": [{"id": "pkg:target", "projectName": "pkg", "targetName": "target", "dependsOn": []}, ...],
  ///   "edges": [["from_id", "to_id"], ...]
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    final edges = <List<String>>[];
    for (final node in nodes) {
      for (final dep in node.dependsOn) {
        edges.add([node.id, dep]);
      }
    }
    return {'nodes': nodes.map((n) => n.toJson()).toList(), 'edges': edges};
  }

  /// Serialise to Graphviz DOT format.
  String toDot() {
    final buf = StringBuffer('digraph task_graph {\n');
    buf.writeln('  rankdir=LR;');

    // Declare all nodes with safe IDs (replace : and - with __)
    for (final node in nodes) {
      final safeId = _dotId(node.id);
      buf.writeln('  $safeId [label="${node.id}"];');
    }

    // Declare edges
    for (final node in nodes) {
      for (final dep in node.dependsOn) {
        buf.writeln('  ${_dotId(node.id)} -> ${_dotId(dep)};');
      }
    }

    buf.write('}');
    return buf.toString();
  }

  static String _dotId(String id) =>
      id.replaceAll(':', '__').replaceAll('-', '_');
}
