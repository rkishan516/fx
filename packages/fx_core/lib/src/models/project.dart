import 'target.dart';

/// The type of a Dart/Flutter project within the workspace.
enum ProjectType {
  dartPackage,
  flutterPackage,
  flutterApp,
  dartCli;

  String toJson() => switch (this) {
    ProjectType.dartPackage => 'dart_package',
    ProjectType.flutterPackage => 'flutter_package',
    ProjectType.flutterApp => 'flutter_app',
    ProjectType.dartCli => 'dart_cli',
  };

  static ProjectType fromJson(String value) => switch (value) {
    'dart_package' => ProjectType.dartPackage,
    'flutter_package' => ProjectType.flutterPackage,
    'flutter_app' => ProjectType.flutterApp,
    'dart_cli' => ProjectType.dartCli,
    _ => ProjectType.dartPackage,
  };
}

/// A discovered project within the fx workspace.
class Project {
  final String name;
  final String path;
  final ProjectType type;
  final List<String> dependencies;
  final Map<String, Target> targets;
  final List<String> tags;
  final bool hasBuildRunner;

  const Project({
    required this.name,
    required this.path,
    required this.type,
    required this.dependencies,
    required this.targets,
    this.tags = const [],
    this.hasBuildRunner = false,
  });

  /// Whether this project uses the Flutter SDK.
  bool get isFlutter =>
      type == ProjectType.flutterPackage || type == ProjectType.flutterApp;

  /// Whether this is a Flutter application (has main.dart entry point).
  bool get isApp => type == ProjectType.flutterApp;

  Project copyWith({
    String? name,
    String? path,
    ProjectType? type,
    List<String>? dependencies,
    Map<String, Target>? targets,
    List<String>? tags,
  }) {
    return Project(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      dependencies: dependencies ?? this.dependencies,
      targets: targets ?? this.targets,
      tags: tags ?? this.tags,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] as String,
      path: json['path'] as String,
      type: ProjectType.fromJson(json['type'] as String),
      dependencies: List<String>.from(json['dependencies'] as List? ?? []),
      targets: (json['targets'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, Target.fromJson(v as Map<String, dynamic>)),
      ),
      tags: List<String>.from(json['tags'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'type': type.toJson(),
    'dependencies': dependencies,
    'targets': targets.map((k, v) => MapEntry(k, v.toJson())),
    'tags': tags,
  };

  @override
  String toString() => 'Project($name, ${type.toJson()})';

  @override
  bool operator ==(Object other) =>
      other is Project && other.name == name && other.path == path;

  @override
  int get hashCode => Object.hash(name, path);
}
