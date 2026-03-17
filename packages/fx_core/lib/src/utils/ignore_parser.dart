import 'dart:io';

import 'package:path/path.dart' as p;

/// Parses `.fxignore` files and tests paths against ignore patterns.
///
/// Supports:
/// - Glob-style patterns (`packages/legacy_*`, `*.generated`)
/// - Directory patterns with trailing `/` (`build/`)
/// - Comment lines starting with `#`
/// - Negation patterns (`!important_pkg`) to re-include
/// - Blank lines (ignored)
class IgnoreParser {
  final List<_IgnoreRule> _rules;

  IgnoreParser._(this._rules);

  /// Creates an [IgnoreParser] from the contents of an ignore file.
  factory IgnoreParser.parse(String content) {
    final rules = <_IgnoreRule>[];
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final negated = line.startsWith('!');
      final pattern = negated ? line.substring(1).trim() : line;
      if (pattern.isEmpty) continue;

      rules.add(_IgnoreRule(pattern: pattern, negated: negated));
    }
    return IgnoreParser._(rules);
  }

  /// Loads and parses `.fxignore` from [workspaceRoot].
  ///
  /// Returns `null` if the file does not exist.
  static IgnoreParser? loadFromWorkspace(String workspaceRoot) {
    final file = File(p.join(workspaceRoot, '.fxignore'));
    if (!file.existsSync()) return null;
    return IgnoreParser.parse(file.readAsStringSync());
  }

  /// Whether [relativePath] should be ignored.
  ///
  /// The path should be relative to the workspace root, using `/` separators.
  /// Last matching rule wins (negation patterns can re-include).
  bool shouldIgnore(String relativePath) {
    // Normalize to forward slashes
    final normalized = relativePath.replaceAll(r'\', '/');

    var ignored = false;
    for (final rule in _rules) {
      if (rule.matches(normalized)) {
        ignored = !rule.negated;
      }
    }
    return ignored;
  }
}

class _IgnoreRule {
  final String pattern;
  final bool negated;

  // Pre-compiled regex for the pattern
  late final RegExp _regex = _compilePattern(pattern);

  _IgnoreRule({required this.pattern, required this.negated});

  bool matches(String path) => _regex.hasMatch(path);

  static RegExp _compilePattern(String pattern) {
    // Remove trailing slash (directory marker) — we match paths regardless
    var p = pattern.endsWith('/')
        ? pattern.substring(0, pattern.length - 1)
        : pattern;

    // If pattern has no slash, match against any path segment
    final matchAnywhere = !p.contains('/');

    // Convert glob to regex
    final buf = StringBuffer();
    if (matchAnywhere) {
      buf.write('(^|/)');
    } else {
      buf.write('^');
    }

    for (var i = 0; i < p.length; i++) {
      final ch = p[i];
      switch (ch) {
        case '*':
          if (i + 1 < p.length && p[i + 1] == '*') {
            // ** matches everything including /
            buf.write('.*');
            i++; // skip second *
            if (i + 1 < p.length && p[i + 1] == '/') i++; // skip trailing /
          } else {
            // * matches everything except /
            buf.write('[^/]*');
          }
        case '?':
          buf.write('[^/]');
        case '.':
          buf.write(r'\.');
        case '(':
        case ')':
        case '{':
        case '}':
        case '+':
        case '^':
        case r'$':
        case '|':
        case r'\':
          buf.write('\\$ch');
        default:
          buf.write(ch);
      }
    }

    // Match the path itself or anything under it
    buf.write(r'(/.*)?$');

    return RegExp(buf.toString());
  }
}
