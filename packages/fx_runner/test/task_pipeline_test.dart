import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:test/test.dart';

void main() {
  group('TaskPipeline', () {
    test('no dependsOn returns single-target list', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      final pipeline = TaskPipeline.resolve('test', config);
      expect(pipeline, ['test']);
    });

    test('resolves dependsOn chain: test dependsOn build => [build, test]', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });
      final pipeline = TaskPipeline.resolve('test', config);
      expect(pipeline, ['build', 'test']);
      expect(pipeline.indexOf('build'), lessThan(pipeline.indexOf('test')));
    });

    test(
      'resolves multi-level chain: deploy dependsOn test, test dependsOn build',
      () {
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'deploy': {
              'executor': 'deploy.sh',
              'dependsOn': ['test'],
            },
            'test': {
              'executor': 'dart test',
              'dependsOn': ['build'],
            },
            'build': {'executor': 'dart compile'},
          },
        });
        final pipeline = TaskPipeline.resolve('deploy', config);
        expect(pipeline, ['build', 'test', 'deploy']);
      },
    );

    test('throws on circular pipeline dependency', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'a': {
            'executor': 'cmd_a',
            'dependsOn': ['b'],
          },
          'b': {
            'executor': 'cmd_b',
            'dependsOn': ['a'],
          },
        },
      });
      expect(
        () => TaskPipeline.resolve('a', config),
        throwsA(isA<StateError>()),
      );
    });

    test('multiple dependencies: deploy depends on build and test', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'deploy': {
            'executor': 'deploy.sh',
            'dependsOn': ['build', 'test'],
          },
          'build': {'executor': 'dart compile'},
          'test': {'executor': 'dart test'},
        },
      });
      final pipeline = TaskPipeline.resolve('deploy', config);
      expect(pipeline, hasLength(3));
      expect(pipeline.last, 'deploy');
      // build and test must come before deploy
      expect(pipeline.indexOf('build'), lessThan(pipeline.indexOf('deploy')));
      expect(pipeline.indexOf('test'), lessThan(pipeline.indexOf('deploy')));
    });

    test('target with empty dependsOn returns single-target list', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test', 'dependsOn': []},
        },
      });
      final pipeline = TaskPipeline.resolve('test', config);
      expect(pipeline, ['test']);
    });

    test('target not in config returns single-target list', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {},
      });
      final pipeline = TaskPipeline.resolve('unknown_target', config);
      expect(pipeline, ['unknown_target']);
    });

    test('preserves ^ prefix in dependsOn entries', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['^build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });
      final pipeline = TaskPipeline.resolve('test', config);
      // ^build should appear before test, with prefix preserved
      expect(pipeline, ['^build', 'test']);
    });

    test('resolves mixed ^ and regular dependsOn', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'e2e': {
            'executor': 'dart test -t e2e',
            'dependsOn': ['^build', 'lint'],
          },
          'build': {'executor': 'dart compile'},
          'lint': {'executor': 'dart analyze'},
        },
      });
      final pipeline = TaskPipeline.resolve('e2e', config);
      expect(pipeline, contains('^build'));
      expect(pipeline, contains('lint'));
      expect(pipeline.last, 'e2e');
    });

    group('isTransitive', () {
      test('returns true for ^-prefixed entries', () {
        expect(TaskPipeline.isTransitive('^build'), isTrue);
      });

      test('returns false for regular entries', () {
        expect(TaskPipeline.isTransitive('build'), isFalse);
      });
    });

    group('stripPrefix', () {
      test('removes ^ prefix', () {
        expect(TaskPipeline.stripPrefix('^build'), 'build');
      });

      test('returns unchanged for non-prefixed', () {
        expect(TaskPipeline.stripPrefix('build'), 'build');
      });
    });

    group('wildcard patterns', () {
      test('expands wildcard dependsOn against known targets', () {
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'deploy': {
              'executor': 'deploy.sh',
              'dependsOn': ['build-*'],
            },
            'build-web': {'executor': 'build_web.sh'},
            'build-mobile': {'executor': 'build_mobile.sh'},
            'lint': {'executor': 'dart analyze'},
          },
        });
        final pipeline = TaskPipeline.resolve('deploy', config);
        expect(pipeline, contains('build-web'));
        expect(pipeline, contains('build-mobile'));
        expect(pipeline, isNot(contains('lint')));
        expect(pipeline.last, 'deploy');
      });

      test('wildcard with ^ prefix expands correctly', () {
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'test': {
              'executor': 'dart test',
              'dependsOn': ['^build-*'],
            },
            'build-lib': {'executor': 'dart compile'},
            'build-app': {'executor': 'flutter build'},
          },
        });
        final pipeline = TaskPipeline.resolve('test', config);
        expect(pipeline, contains('^build-lib'));
        expect(pipeline, contains('^build-app'));
        expect(pipeline.last, 'test');
      });

      test('wildcard matching no targets produces empty expansion', () {
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'deploy': {
              'executor': 'deploy.sh',
              'dependsOn': ['no-match-*'],
            },
          },
        });
        final pipeline = TaskPipeline.resolve('deploy', config);
        expect(pipeline, ['deploy']);
      });
    });

    group('resolveEntries', () {
      test('returns DependsOnEntry objects preserving params', () {
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'e2e': {
              'executor': 'dart test -t e2e',
              'dependsOn': [
                {'target': 'build', 'params': 'forward'},
                'lint',
              ],
            },
            'build': {'executor': 'dart compile'},
            'lint': {'executor': 'dart analyze'},
          },
        });
        final entries = TaskPipeline.resolveEntries('e2e', config);
        expect(entries, hasLength(3));
        final buildEntry = entries.firstWhere((e) => e.target == 'build');
        expect(buildEntry.params, isTrue);
        final lintEntry = entries.firstWhere((e) => e.target == 'lint');
        expect(lintEntry.params, isFalse);
      });

      test('expands wildcards in resolveEntries', () {
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'deploy': {
              'executor': 'deploy.sh',
              'dependsOn': ['build-*'],
            },
            'build-web': {'executor': 'build_web.sh'},
            'build-api': {'executor': 'build_api.sh'},
          },
        });
        final entries = TaskPipeline.resolveEntries('deploy', config);
        expect(
          entries.map((e) => e.target),
          containsAll(['build-web', 'build-api', 'deploy']),
        );
      });
    });

    test(
      'diamond pipeline: deploy depends on build and test, both depend on lint',
      () {
        final config = FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'deploy': {
              'executor': 'deploy.sh',
              'dependsOn': ['build', 'test'],
            },
            'build': {
              'executor': 'dart compile',
              'dependsOn': ['lint'],
            },
            'test': {
              'executor': 'dart test',
              'dependsOn': ['lint'],
            },
            'lint': {'executor': 'dart analyze'},
          },
        });
        final pipeline = TaskPipeline.resolve('deploy', config);
        // lint must come first, deploy must be last
        expect(pipeline.first, 'lint');
        expect(pipeline.last, 'deploy');
        // lint should appear only once (deduplication)
        expect(pipeline.where((t) => t == 'lint'), hasLength(1));
      },
    );
  });
}
