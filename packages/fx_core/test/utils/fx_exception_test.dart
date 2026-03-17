import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('FxException', () {
    test('stores message', () {
      const ex = FxException('something broke');
      expect(ex.message, equals('something broke'));
    });

    test('hint defaults to null', () {
      const ex = FxException('error');
      expect(ex.hint, isNull);
    });

    test('stores hint when provided', () {
      const ex = FxException('error', hint: 'try this');
      expect(ex.hint, equals('try this'));
    });

    test('toString without hint', () {
      const ex = FxException('file not found');
      expect(ex.toString(), equals('FxException: file not found'));
    });

    test('toString with hint includes hint', () {
      const ex = FxException('missing config', hint: 'run fx init');
      expect(ex.toString(), contains('FxException: missing config'));
      expect(ex.toString(), contains('Hint: run fx init'));
    });

    test('implements Exception', () {
      const ex = FxException('test');
      expect(ex, isA<Exception>());
    });
  });

  group('WorkspaceNotFoundException', () {
    test('includes path in message', () {
      const ex = WorkspaceNotFoundException('/some/path');
      expect(ex.message, contains('/some/path'));
    });

    test('has hint about fx init', () {
      const ex = WorkspaceNotFoundException('/path');
      expect(ex.hint, contains('fx init'));
    });

    test('extends FxException', () {
      const ex = WorkspaceNotFoundException('/path');
      expect(ex, isA<FxException>());
    });

    test('toString includes path and hint', () {
      const ex = WorkspaceNotFoundException('/my/dir');
      final str = ex.toString();
      expect(str, contains('/my/dir'));
      expect(str, contains('Hint:'));
    });
  });

  group('ConfigException', () {
    test('stores message', () {
      const ex = ConfigException('invalid target');
      expect(ex.message, equals('invalid target'));
    });

    test('stores optional hint', () {
      const ex = ConfigException('bad yaml', hint: 'check syntax');
      expect(ex.hint, equals('check syntax'));
    });

    test('extends FxException', () {
      const ex = ConfigException('error');
      expect(ex, isA<FxException>());
    });
  });
}
