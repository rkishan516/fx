import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('PathTokens', () {
    test('resolves {projectRoot} token', () {
      final result = PathTokens.resolve(
        '{projectRoot}/lib/**',
        projectRoot: '/ws/packages/my_pkg',
        workspaceRoot: '/ws',
      );
      expect(result, '/ws/packages/my_pkg/lib/**');
    });

    test('resolves {workspaceRoot} token', () {
      final result = PathTokens.resolve(
        '{workspaceRoot}/tools/**',
        projectRoot: '/ws/packages/my_pkg',
        workspaceRoot: '/ws',
      );
      expect(result, '/ws/tools/**');
    });

    test('resolves both tokens in one pattern', () {
      final result = PathTokens.resolve(
        '{projectRoot}/lib/** {workspaceRoot}/shared/**',
        projectRoot: '/ws/packages/a',
        workspaceRoot: '/ws',
      );
      expect(result, '/ws/packages/a/lib/** /ws/shared/**');
    });

    test('resolves {projectName} token', () {
      final result = PathTokens.resolve(
        '{workspaceRoot}/dist/{projectName}',
        projectRoot: '/ws/packages/my_pkg',
        workspaceRoot: '/ws',
        projectName: 'my_pkg',
      );
      expect(result, '/ws/dist/my_pkg');
    });

    test('resolves all three tokens in one pattern', () {
      final result = PathTokens.resolve(
        '{projectRoot}/build/{projectName} {workspaceRoot}/out',
        projectRoot: '/ws/packages/app',
        workspaceRoot: '/ws',
        projectName: 'app',
      );
      expect(result, '/ws/packages/app/build/app /ws/out');
    });

    test('returns unchanged when no tokens present', () {
      final result = PathTokens.resolve(
        'lib/**',
        projectRoot: '/ws/packages/a',
        workspaceRoot: '/ws',
      );
      expect(result, 'lib/**');
    });

    test('resolveAll processes list of patterns', () {
      final result = PathTokens.resolveAll(
        ['{projectRoot}/lib/**', '{workspaceRoot}/config.yaml'],
        projectRoot: '/ws/packages/pkg',
        workspaceRoot: '/ws',
      );
      expect(result, ['/ws/packages/pkg/lib/**', '/ws/config.yaml']);
    });

    test('resolveAll returns empty list for empty input', () {
      final result = PathTokens.resolveAll(
        [],
        projectRoot: '/ws/packages/pkg',
        workspaceRoot: '/ws',
      );
      expect(result, isEmpty);
    });
  });
}
