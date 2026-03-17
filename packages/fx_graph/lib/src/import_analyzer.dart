import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;

/// Result of analyzing imports within a project.
class ImportAnalysis {
  /// Maps file path to the list of packages it imports.
  final Map<String, Set<String>> fileImports;

  /// Maps package name to the set of files that import it.
  final Map<String, Set<String>> packageImporters;

  const ImportAnalysis({
    required this.fileImports,
    required this.packageImporters,
  });
}

/// Analyzes Dart import statements at the file level for fine-grained
/// dependency detection.
///
/// Unlike package-level analysis (pubspec.yaml), this catches actual
/// source-level dependencies including transitive imports.
class ImportAnalyzer {
  static final _importRegex = RegExp(
    r'''^\s*import\s+['"]package:(\w+)\/''',
    multiLine: true,
  );

  /// Analyze all Dart files in [projectPath] and extract package imports.
  static Future<ImportAnalysis> analyze(String projectPath) async {
    final fileImports = <String, Set<String>>{};
    final packageImporters = <String, Set<String>>{};

    final libDir = Directory(p.join(projectPath, 'lib'));
    if (!libDir.existsSync()) {
      return const ImportAnalysis(fileImports: {}, packageImporters: {});
    }

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final content = await entity.readAsString();
      final imports = _extractImports(content);
      final relPath = p.relative(entity.path, from: projectPath);

      if (imports.isNotEmpty) {
        fileImports[relPath] = imports;
        for (final pkg in imports) {
          packageImporters.putIfAbsent(pkg, () => {}).add(relPath);
        }
      }
    }

    return ImportAnalysis(
      fileImports: fileImports,
      packageImporters: packageImporters,
    );
  }

  /// Analyze imports across all projects and return a file-level dependency map.
  ///
  /// Returns a map from project name to the set of package names it actually
  /// imports at the source level (may differ from pubspec.yaml declarations).
  static Future<Map<String, Set<String>>> analyzeWorkspace(
    String workspaceRoot,
    List<String> projectPaths,
  ) async {
    final result = <String, Set<String>>{};

    for (final projectPath in projectPaths) {
      final projectName = p.basename(projectPath);
      final analysis = await analyze(projectPath);

      final allImported = <String>{};
      for (final imports in analysis.fileImports.values) {
        allImported.addAll(imports);
      }
      // Remove self-imports
      allImported.remove(projectName);

      result[projectName] = allImported;
    }

    return result;
  }

  /// Detect workspace projects imported by [project] but not declared
  /// in its `pubspec.yaml` dependencies.
  ///
  /// Returns a list of workspace project names that are implicitly depended
  /// on via `package:` imports but missing from pubspec path dependencies.
  static Future<List<String>> detectImplicitDependencies({
    required Project project,
    required List<Project> allProjects,
  }) async {
    final analysis = await analyze(project.path);
    if (analysis.fileImports.isEmpty) return const [];

    final allImported = <String>{};
    for (final imports in analysis.fileImports.values) {
      allImported.addAll(imports);
    }
    allImported.remove(project.name); // remove self-imports

    // Filter to workspace project names only
    final workspaceNames = allProjects.map((p) => p.name).toSet();
    final workspaceImports = allImported.intersection(workspaceNames);

    // Find imports not declared in pubspec dependencies
    final declaredDeps = project.dependencies.toSet();
    final implicit = workspaceImports.difference(declaredDeps);

    return implicit.toList()..sort();
  }

  /// Detect all implicit workspace dependencies across all projects.
  ///
  /// Returns a map from project name to list of undeclared workspace
  /// dependencies found via import analysis.
  static Future<Map<String, List<String>>> detectAllImplicit(
    List<Project> projects,
  ) async {
    final result = <String, List<String>>{};

    for (final project in projects) {
      final implicit = await detectImplicitDependencies(
        project: project,
        allProjects: projects,
      );
      if (implicit.isNotEmpty) {
        result[project.name] = implicit;
      }
    }

    return result;
  }

  /// Extract package names from import statements.
  static Set<String> _extractImports(String content) {
    final imports = <String>{};
    for (final match in _importRegex.allMatches(content)) {
      final pkg = match.group(1);
      if (pkg != null) imports.add(pkg);
    }
    return imports;
  }
}
