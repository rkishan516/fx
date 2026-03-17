import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('FxConfig.resolveTarget', () {
    test('returns null when no target exists anywhere', () {
      final config = FxConfig.defaults();
      expect(config.resolveTarget('nonexistent'), isNull);
    });

    test('returns targetDefault when no workspace or project target', () {
      final config = FxConfig(
        packages: ['packages/*'],
        targets: {},
        cacheConfig: CacheConfig.defaults(),
        generators: [],
        targetDefaults: {'test': Target(name: 'test', executor: 'dart test')},
      );

      final resolved = config.resolveTarget('test');
      expect(resolved, isNotNull);
      expect(resolved!.executor, 'dart test');
    });

    test('workspace target overrides targetDefault', () {
      final config = FxConfig(
        packages: ['packages/*'],
        targets: {'test': Target(name: 'test', executor: 'flutter test')},
        cacheConfig: CacheConfig.defaults(),
        generators: [],
        targetDefaults: {'test': Target(name: 'test', executor: 'dart test')},
      );

      final resolved = config.resolveTarget('test');
      expect(resolved!.executor, 'flutter test');
    });

    test('project target overrides workspace and defaults', () {
      final config = FxConfig(
        packages: ['packages/*'],
        targets: {'test': Target(name: 'test', executor: 'flutter test')},
        cacheConfig: CacheConfig.defaults(),
        generators: [],
        targetDefaults: {'test': Target(name: 'test', executor: 'dart test')},
      );

      final projectTarget = Target(name: 'test', executor: 'custom test');
      final resolved = config.resolveTarget(
        'test',
        projectTarget: projectTarget,
      );
      expect(resolved!.executor, 'custom test');
    });

    test('merges dependsOn from defaults when ws/project omit them', () {
      final config = FxConfig(
        packages: ['packages/*'],
        targets: {'test': Target(name: 'test', executor: 'dart test')},
        cacheConfig: CacheConfig.defaults(),
        generators: [],
        targetDefaults: {
          'test': Target(
            name: 'test',
            executor: '',
            dependsOnEntries: [DependsOnEntry(target: 'build')],
          ),
        },
      );

      final resolved = config.resolveTarget('test');
      expect(resolved!.executor, 'dart test');
      expect(resolved.dependsOn, ['build']);
    });
  });

  group('FxConfig.resolveInputPatterns', () {
    test('resolves named inputs', () {
      final config = FxConfig(
        packages: [],
        targets: {},
        cacheConfig: CacheConfig.defaults(),
        generators: [],
        namedInputs: {
          'default': NamedInput(name: 'default', patterns: ['lib/**/*.dart']),
          'production': NamedInput(
            name: 'production',
            patterns: ['{default}', '!lib/**/*_test.dart'],
          ),
        },
      );

      final resolved = config.resolveInputPatterns(['{production}']);
      expect(resolved, contains('lib/**/*.dart'));
      expect(resolved, contains('!lib/**/*_test.dart'));
    });

    test('passes through literal patterns', () {
      final config = FxConfig.defaults();
      final resolved = config.resolveInputPatterns(['lib/**/*.dart']);
      expect(resolved, ['lib/**/*.dart']);
    });
  });

  group('FxConfig.fromYaml', () {
    test('parses targetDefaults', () {
      final config = FxConfig.fromYaml({
        'targetDefaults': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['build'],
          },
          'build': {'executor': 'dart compile'},
        },
      });

      expect(config.targetDefaults, hasLength(2));
      expect(config.targetDefaults['test']!.executor, 'dart test');
      expect(config.targetDefaults['test']!.dependsOn, ['build']);
    });

    test('parses namedInputs', () {
      final config = FxConfig.fromYaml({
        'namedInputs': {
          'default': ['lib/**/*.dart', 'pubspec.yaml'],
          'production': ['{default}', '!**/*_test.dart'],
        },
      });

      expect(config.namedInputs, hasLength(2));
      expect(config.namedInputs['default']!.patterns, [
        'lib/**/*.dart',
        'pubspec.yaml',
      ]);
    });

    test('parses moduleBoundaries', () {
      final config = FxConfig.fromYaml({
        'moduleBoundaries': [
          {
            'sourceTag': 'scope:app',
            'onlyDependOnLibsWithTags': ['scope:shared', 'scope:core'],
          },
          {
            'sourceTag': 'scope:core',
            'notDependOnLibsWithTags': ['scope:app'],
          },
        ],
      });

      expect(config.moduleBoundaries, hasLength(2));
      expect(config.moduleBoundaries[0].sourceTag, 'scope:app');
      expect(config.moduleBoundaries[0].allowedTags, [
        'scope:shared',
        'scope:core',
      ]);
      expect(config.moduleBoundaries[1].deniedTags, ['scope:app']);
    });

    test('parses remoteUrl in cache config', () {
      final config = FxConfig.fromYaml({
        'cache': {'enabled': true, 'remoteUrl': 'https://cache.example.com'},
      });

      expect(config.cacheConfig.remoteUrl, 'https://cache.example.com');
    });
  });

  group('Target.fromYaml', () {
    test('accepts command as alias for executor', () {
      final target = Target.fromYaml('test', {'command': 'dart test'});
      expect(target.executor, 'dart test');
    });

    test('executor takes precedence over command', () {
      final target = Target.fromYaml('test', {
        'executor': 'dart test',
        'command': 'flutter test',
      });
      expect(target.executor, 'dart test');
    });
  });

  group('Target continuous flag', () {
    test('fromYaml parses continuous: true', () {
      final target = Target.fromYaml('serve', {
        'executor': 'dart run',
        'continuous': true,
      });
      expect(target.continuous, isTrue);
    });

    test('fromYaml defaults continuous to false when absent', () {
      final target = Target.fromYaml('test', {'executor': 'dart test'});
      expect(target.continuous, isFalse);
    });

    test('fromJson round-trips continuous flag', () {
      final original = Target(
        name: 'serve',
        executor: 'dart run',
        continuous: true,
      );
      final json = original.toJson();
      final restored = Target.fromJson(json);
      expect(restored.continuous, isTrue);
    });

    test('toJson includes continuous field when true', () {
      final target = Target(
        name: 'serve',
        executor: 'dart run',
        continuous: true,
      );
      expect(target.toJson()['continuous'], isTrue);
    });

    test('toJson omits continuous field when false', () {
      final target = Target(name: 'test', executor: 'dart test');
      expect(target.toJson().containsKey('continuous'), isFalse);
    });

    test('copyWith can override continuous', () {
      final target = Target(name: 'serve', executor: 'dart run');
      final updated = target.copyWith(continuous: true);
      expect(updated.continuous, isTrue);
      expect(target.continuous, isFalse); // original unchanged
    });
  });

  group('Project tags', () {
    test('Project.fromJson parses tags', () {
      final project = Project.fromJson({
        'name': 'core',
        'path': '/workspace/packages/core',
        'type': 'dart_package',
        'tags': ['scope:shared', 'type:lib'],
      });

      expect(project.tags, ['scope:shared', 'type:lib']);
    });

    test('Project.toJson includes tags', () {
      final project = Project(
        name: 'core',
        path: '/workspace/packages/core',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
        tags: ['scope:shared'],
      );

      expect(project.toJson()['tags'], ['scope:shared']);
    });

    test('Project.copyWith updates tags', () {
      final project = Project(
        name: 'core',
        path: '/path',
        type: ProjectType.dartPackage,
        dependencies: [],
        targets: {},
        tags: ['old'],
      );

      final updated = project.copyWith(tags: ['new']);
      expect(updated.tags, ['new']);
      expect(project.tags, ['old']); // original unchanged
    });
  });
}
