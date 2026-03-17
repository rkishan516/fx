import 'package:yaml/yaml.dart';

import 'fx_exception.dart';

/// Result of parsing a pubspec.yaml file.
class PubspecData {
  final String name;
  final Map<String, String> pathDependencies;
  final bool hasFlutterDependency;
  final bool hasBuildRunner;
  final bool hasFxSection;
  final List<String> workspaceMembers;
  final Map<dynamic, dynamic> rawYaml;

  const PubspecData({
    required this.name,
    required this.pathDependencies,
    required this.hasFlutterDependency,
    required this.hasBuildRunner,
    required this.hasFxSection,
    required this.workspaceMembers,
    required this.rawYaml,
  });
}

/// Parses pubspec.yaml files to extract fx-relevant information.
class PubspecParser {
  /// Parse pubspec.yaml content from a string.
  ///
  /// Throws [FxException] if the YAML is malformed.
  static PubspecData parse(String content, {required String path}) {
    final YamlMap doc;
    try {
      final raw = loadYaml(content);
      if (raw is! YamlMap) {
        throw FxException('pubspec.yaml is not a valid YAML map', hint: path);
      }
      doc = raw;
    } on YamlException catch (e) {
      throw FxException(
        'Malformed YAML in pubspec.yaml: ${e.message}',
        hint: path,
      );
    } catch (e) {
      if (e is FxException) rethrow;
      throw FxException('Failed to parse pubspec.yaml: $e', hint: path);
    }

    final name = doc['name']?.toString() ?? '';
    final pathDeps = _extractPathDeps(doc);
    final hasFlutter = _hasFlutterDep(doc);
    final hasBuildRunner = _hasDep(doc, 'build_runner');
    final hasFx = doc.containsKey('fx');
    final workspaceMembers = _extractWorkspaceMembers(doc);

    return PubspecData(
      name: name,
      pathDependencies: pathDeps,
      hasFlutterDependency: hasFlutter,
      hasBuildRunner: hasBuildRunner,
      hasFxSection: hasFx,
      workspaceMembers: workspaceMembers,
      rawYaml: doc,
    );
  }

  static Map<String, String> _extractPathDeps(YamlMap doc) {
    final result = <String, String>{};
    final sections = ['dependencies', 'dev_dependencies'];
    for (final section in sections) {
      final deps = doc[section];
      if (deps is! YamlMap) continue;
      for (final entry in deps.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is YamlMap && val.containsKey('path')) {
          result[key] = val['path'].toString();
        }
      }
    }
    return result;
  }

  static bool _hasFlutterDep(YamlMap doc) {
    return _hasDep(doc, 'flutter');
  }

  static bool _hasDep(YamlMap doc, String depName) {
    for (final section in ['dependencies', 'dev_dependencies']) {
      final deps = doc[section];
      if (deps is! YamlMap) continue;
      for (final key in deps.keys) {
        if (key.toString() == depName) return true;
      }
    }
    return false;
  }

  static List<String> _extractWorkspaceMembers(YamlMap doc) {
    final workspace = doc['workspace'];
    if (workspace is! YamlList) return [];
    return workspace.map((e) => e.toString()).toList();
  }
}
