/// Resolves `{projectRoot}`, `{workspaceRoot}`, and `{projectName}` path
/// tokens in patterns.
class PathTokens {
  /// Replace `{projectRoot}`, `{workspaceRoot}`, and `{projectName}` in a
  /// pattern string.
  static String resolve(
    String pattern, {
    required String projectRoot,
    required String workspaceRoot,
    String? projectName,
  }) {
    var result = pattern
        .replaceAll('{projectRoot}', projectRoot)
        .replaceAll('{workspaceRoot}', workspaceRoot);
    if (projectName != null) {
      result = result.replaceAll('{projectName}', projectName);
    }
    return result;
  }

  /// Resolve tokens in a list of patterns.
  static List<String> resolveAll(
    List<String> patterns, {
    required String projectRoot,
    required String workspaceRoot,
    String? projectName,
  }) {
    return patterns
        .map(
          (p) => resolve(
            p,
            projectRoot: projectRoot,
            workspaceRoot: workspaceRoot,
            projectName: projectName,
          ),
        )
        .toList();
  }
}
