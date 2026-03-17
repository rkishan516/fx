import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('IgnoreParser.parse', () {
    test('ignores blank lines and comments', () {
      final parser = IgnoreParser.parse('''
# This is a comment

# Another comment
legacy_pkg
''');
      expect(parser.shouldIgnore('legacy_pkg'), isTrue);
      expect(parser.shouldIgnore('other_pkg'), isFalse);
    });

    test('matches simple directory name anywhere in path', () {
      final parser = IgnoreParser.parse('build');
      expect(parser.shouldIgnore('build'), isTrue);
      expect(parser.shouldIgnore('packages/build'), isTrue);
      expect(parser.shouldIgnore('packages/my_build'), isFalse);
    });

    test('matches glob wildcard', () {
      final parser = IgnoreParser.parse('legacy_*');
      expect(parser.shouldIgnore('legacy_auth'), isTrue);
      expect(parser.shouldIgnore('legacy_core'), isTrue);
      expect(parser.shouldIgnore('packages/legacy_auth'), isTrue);
      expect(parser.shouldIgnore('new_auth'), isFalse);
    });

    test('matches path with slash as anchored pattern', () {
      final parser = IgnoreParser.parse('packages/legacy_*');
      expect(parser.shouldIgnore('packages/legacy_auth'), isTrue);
      expect(parser.shouldIgnore('apps/legacy_auth'), isFalse);
    });

    test('matches directory pattern with trailing slash', () {
      final parser = IgnoreParser.parse('build/');
      expect(parser.shouldIgnore('build'), isTrue);
      expect(parser.shouldIgnore('packages/build'), isTrue);
    });

    test('supports negation patterns to re-include', () {
      final parser = IgnoreParser.parse('''
legacy_*
!legacy_core
''');
      expect(parser.shouldIgnore('legacy_auth'), isTrue);
      expect(parser.shouldIgnore('legacy_core'), isFalse);
    });

    test('last matching rule wins', () {
      final parser = IgnoreParser.parse('''
packages/old
!packages/old
packages/old
''');
      expect(parser.shouldIgnore('packages/old'), isTrue);
    });

    test('double star matches nested paths', () {
      final parser = IgnoreParser.parse('**/generated');
      expect(parser.shouldIgnore('generated'), isTrue);
      expect(parser.shouldIgnore('packages/foo/generated'), isTrue);
      expect(parser.shouldIgnore('a/b/c/generated'), isTrue);
    });

    test('question mark matches single character', () {
      final parser = IgnoreParser.parse('pkg_?');
      expect(parser.shouldIgnore('pkg_a'), isTrue);
      expect(parser.shouldIgnore('pkg_ab'), isFalse);
    });

    test('empty content produces no rules', () {
      final parser = IgnoreParser.parse('');
      expect(parser.shouldIgnore('anything'), isFalse);
    });

    test('handles backslash path separators', () {
      final parser = IgnoreParser.parse('packages/legacy');
      expect(parser.shouldIgnore(r'packages\legacy'), isTrue);
    });

    test('matches subdirectories of ignored path', () {
      final parser = IgnoreParser.parse('packages/old');
      expect(parser.shouldIgnore('packages/old'), isTrue);
      expect(parser.shouldIgnore('packages/old/sub'), isTrue);
    });
  });

  group('IgnoreParser.loadFromWorkspace', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fx_ignore_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('returns null when .fxignore does not exist', () {
      final parser = IgnoreParser.loadFromWorkspace(tempDir.path);
      expect(parser, isNull);
    });

    test('loads and parses .fxignore from workspace root', () {
      File(p.join(tempDir.path, '.fxignore')).writeAsStringSync('legacy_pkg\n');
      final parser = IgnoreParser.loadFromWorkspace(tempDir.path);
      expect(parser, isNotNull);
      expect(parser!.shouldIgnore('legacy_pkg'), isTrue);
    });
  });
}
