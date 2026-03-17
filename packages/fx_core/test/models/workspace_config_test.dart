import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('FxConfig', () {
    test('parses minimal config from yaml map', () {
      final yaml = {
        'fx': {
          'packages': ['packages/*'],
        },
      };
      final config = FxConfig.fromYaml(yaml['fx'] as Map);
      expect(config.packages, ['packages/*']);
      expect(config.targets, isEmpty);
      expect(config.cacheConfig.enabled, isFalse);
    });

    test('parses full config with targets and cache', () {
      final yaml = {
        'packages': ['packages/*', 'apps/*'],
        'targets': {
          'test': {
            'executor': 'dart test',
            'dependsOn': ['build'],
            'inputs': ['lib/**', 'test/**'],
          },
          'build': {'executor': 'dart compile'},
        },
        'cache': {'enabled': true, 'directory': '.fx_cache'},
        'generators': ['packages/generators/*'],
      };
      final config = FxConfig.fromYaml(yaml);
      expect(config.packages, containsAll(['packages/*', 'apps/*']));
      expect(config.targets['test']?.executor, 'dart test');
      expect(config.targets['test']?.dependsOn, ['build']);
      expect(config.targets['build']?.executor, 'dart compile');
      expect(config.cacheConfig.enabled, isTrue);
      expect(config.cacheConfig.directory, '.fx_cache');
      expect(config.generators, ['packages/generators/*']);
    });

    test('returns null for missing target', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.targets['nonexistent'], isNull);
    });

    test('cacheConfig defaults when cache section absent', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.cacheConfig.enabled, isFalse);
      expect(config.cacheConfig.directory, '.fx_cache');
    });

    test('target inputs default to empty when not specified', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      expect(config.targets['test']?.inputs, isEmpty);
    });

    test('target dependsOn defaults to empty when not specified', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      expect(config.targets['test']?.dependsOn, isEmpty);
    });

    test('multiple package glob patterns', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*', 'apps/*', 'tools/*'],
      });
      expect(config.packages, hasLength(3));
      expect(config.packages, contains('apps/*'));
    });

    test('generators defaults to empty when not specified', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.generators, isEmpty);
    });

    test('empty targets map when not specified', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.targets, isEmpty);
    });

    test('cache with only enabled field uses default directory', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'cache': {'enabled': true},
      });
      expect(config.cacheConfig.enabled, isTrue);
      expect(config.cacheConfig.directory, '.fx_cache');
    });

    test('cache with custom directory', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'cache': {'enabled': true, 'directory': 'build/cache'},
      });
      expect(config.cacheConfig.directory, 'build/cache');
    });

    test('target cache defaults to true', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      expect(config.targets['test']?.cache, isTrue);
    });

    test('target cache can be set to false', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test', 'cache': false},
        },
      });
      expect(config.targets['test']?.cache, isFalse);
    });

    test('target options parsed from yaml', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'build': {
            'executor': 'dart compile',
            'options': {'release': true, 'output': 'dist'},
          },
        },
      });
      expect(config.targets['build']?.options, {
        'release': true,
        'output': 'dist',
      });
    });

    test('target options default to empty map', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'test': {'executor': 'dart test'},
        },
      });
      expect(config.targets['test']?.options, isEmpty);
    });

    test('resolveTarget merges cache and options from defaults', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targetDefaults': {
          'build': {
            'executor': 'dart compile',
            'cache': false,
            'options': {'mode': 'debug'},
          },
        },
      });
      final resolved = config.resolveTarget('build');
      expect(resolved?.cache, isFalse);
      expect(resolved?.options, {'mode': 'debug'});
    });

    test('resolveTarget project target overrides cache', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targets': {
          'build': {'executor': 'dart compile', 'cache': true},
        },
      });
      final projectTarget = Target(
        name: 'build',
        executor: 'dart compile',
        cache: false,
      );
      final resolved = config.resolveTarget(
        'build',
        projectTarget: projectTarget,
      );
      expect(resolved?.cache, isFalse);
    });

    test('resolveTarget merges options across levels', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'targetDefaults': {
          'build': {
            'executor': 'dart compile',
            'options': {'mode': 'debug', 'verbose': true},
          },
        },
        'targets': {
          'build': {
            'executor': 'dart compile',
            'options': {'mode': 'release'},
          },
        },
      });
      final resolved = config.resolveTarget('build');
      // workspace options override defaults
      expect(resolved?.options['mode'], 'release');
      expect(resolved?.options['verbose'], isTrue);
    });

    test('defaultBase defaults to main', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.defaultBase, 'main');
    });

    test('defaultBase can be customized', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'defaultBase': 'develop',
      });
      expect(config.defaultBase, 'develop');
    });

    test('configurations parsed from yaml', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'configurations': {
          'production': {'minify': true},
          'development': {'sourceMaps': true},
        },
      });
      expect(config.configurations, hasLength(2));
      expect(config.configurations['production']?['minify'], isTrue);
    });

    test('parallel defaults to null when not specified', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.parallel, isNull);
    });

    test('parallel parsed from yaml', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'parallel': 4,
      });
      expect(config.parallel, 4);
    });

    test('skipCache defaults to false', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.skipCache, isFalse);
    });

    test('skipCache can be set to true', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'skipCache': true,
      });
      expect(config.skipCache, isTrue);
    });

    test('release config parsed from yaml', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'release': {
          'projectsRelationship': 'independent',
          'releaseTagPattern': '{projectName}@{version}',
          'changelog': {'workspaceChangelog': true},
          'git': {'commit': true, 'tag': true},
        },
      });
      expect(config.releaseConfig, isNotNull);
      expect(config.releaseConfig!.projectsRelationship, 'independent');
      expect(
        config.releaseConfig!.releaseTagPattern,
        '{projectName}@{version}',
      );
      expect(config.releaseConfig!.changelog['workspaceChangelog'], isTrue);
      expect(config.releaseConfig!.git['commit'], isTrue);
    });

    test('release config defaults to null', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.releaseConfig, isNull);
    });

    test('sync config parsed from yaml', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'sync': {
          'applyChanges': true,
          'disabledGenerators': ['gen1', 'gen2'],
        },
      });
      expect(config.syncConfig, isNotNull);
      expect(config.syncConfig!.applyChanges, isTrue);
      expect(config.syncConfig!.disabledGenerators, ['gen1', 'gen2']);
    });

    test('sync config defaults to null', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.syncConfig, isNull);
    });

    test('conformanceRules parsed from yaml', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'conformanceRules': [
          {
            'id': 'must-test',
            'type': 'require-target',
            'options': {'target': 'test'},
          },
          {'id': 'needs-tags', 'type': 'require-tags'},
        ],
      });
      expect(config.conformanceRules, hasLength(2));
      expect(config.conformanceRules[0].id, 'must-test');
      expect(config.conformanceRules[0].type, 'require-target');
      expect(config.conformanceRules[0].options['target'], 'test');
      expect(config.conformanceRules[1].id, 'needs-tags');
    });

    test('conformanceRules defaults to empty', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.conformanceRules, isEmpty);
    });

    test('captureStderr defaults to false', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.captureStderr, isFalse);
    });

    test('captureStderr can be set to true', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'captureStderr': true,
      });
      expect(config.captureStderr, isTrue);
    });
  });

  group('CacheConfig', () {
    test('defaults', () {
      final config = CacheConfig.defaults();
      expect(config.enabled, isFalse);
      expect(config.directory, '.fx_cache');
    });
  });

  group('PluginConfig', () {
    test('fromYaml parses string as path only', () {
      final pc = PluginConfig.fromYaml('packages/generators/*');
      expect(pc.plugin, 'packages/generators/*');
      expect(pc.include, isEmpty);
      expect(pc.exclude, isEmpty);
    });

    test('fromYaml parses map with include/exclude', () {
      final pc = PluginConfig.fromYaml({
        'plugin': 'packages/generators/*',
        'include': ['app_*', 'web_*'],
        'exclude': ['*_test'],
      });
      expect(pc.plugin, 'packages/generators/*');
      expect(pc.include, ['app_*', 'web_*']);
      expect(pc.exclude, ['*_test']);
    });

    test('appliesTo returns true when no filters', () {
      final pc = PluginConfig(plugin: 'gen/*');
      expect(pc.appliesTo('anything'), isTrue);
    });

    test('appliesTo filters by include glob', () {
      final pc = PluginConfig(plugin: 'gen/*', include: ['app_*']);
      expect(pc.appliesTo('app_web'), isTrue);
      expect(pc.appliesTo('lib_core'), isFalse);
    });

    test('appliesTo filters by exclude glob', () {
      final pc = PluginConfig(plugin: 'gen/*', exclude: ['*_test']);
      expect(pc.appliesTo('my_app'), isTrue);
      expect(pc.appliesTo('my_test'), isFalse);
    });

    test('appliesTo include + exclude combined', () {
      final pc = PluginConfig(
        plugin: 'gen/*',
        include: ['app_*'],
        exclude: ['app_legacy'],
      );
      expect(pc.appliesTo('app_web'), isTrue);
      expect(pc.appliesTo('app_legacy'), isFalse);
      expect(pc.appliesTo('lib_core'), isFalse);
    });

    test('appliesTo exact match (no wildcard)', () {
      final pc = PluginConfig(plugin: 'gen/*', include: ['my_app']);
      expect(pc.appliesTo('my_app'), isTrue);
      expect(pc.appliesTo('my_app2'), isFalse);
    });
  });

  group('FxConfig plugins', () {
    test('pluginConfigs parsed from yaml', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
        'plugins': [
          'packages/generators/*',
          {
            'plugin': 'packages/custom/*',
            'include': ['app_*'],
            'exclude': ['app_legacy'],
          },
        ],
      });
      expect(config.pluginConfigs, hasLength(2));
      expect(config.pluginConfigs[0].plugin, 'packages/generators/*');
      expect(config.pluginConfigs[0].include, isEmpty);
      expect(config.pluginConfigs[1].plugin, 'packages/custom/*');
      expect(config.pluginConfigs[1].include, ['app_*']);
      expect(config.pluginConfigs[1].exclude, ['app_legacy']);
    });

    test('pluginConfigs defaults to empty', () {
      final config = FxConfig.fromYaml({
        'packages': ['packages/*'],
      });
      expect(config.pluginConfigs, isEmpty);
    });
  });

  group('PluginConfig enhanced fields', () {
    test('parses options map from YAML', () {
      final pc = PluginConfig.fromYaml({
        'plugin': 'my_plugin',
        'options': {'key': 'value', 'count': 42},
      });
      expect(pc.options['key'], 'value');
      expect(pc.options['count'], 42);
    });

    test('options defaults to empty map', () {
      final pc = PluginConfig.fromYaml('my_plugin');
      expect(pc.options, isEmpty);
    });

    test('parses capabilities list from YAML', () {
      final pc = PluginConfig.fromYaml({
        'plugin': 'my_plugin',
        'capabilities': ['inference', 'migrations'],
      });
      expect(pc.capabilities, contains(PluginCapability.inference));
      expect(pc.capabilities, contains(PluginCapability.migrations));
    });

    test('capabilities defaults to empty set', () {
      final pc = PluginConfig.fromYaml('my_plugin');
      expect(pc.capabilities, isEmpty);
    });

    test('parses priority from YAML', () {
      final pc = PluginConfig.fromYaml({'plugin': 'my_plugin', 'priority': 10});
      expect(pc.priority, 10);
    });

    test('priority defaults to 0', () {
      final pc = PluginConfig.fromYaml('my_plugin');
      expect(pc.priority, 0);
    });

    test(
      'backward compatibility: existing configs without new fields still parse',
      () {
        final pc = PluginConfig.fromYaml({
          'plugin': 'packages/generators/*',
          'include': ['app_*'],
          'exclude': ['*_test'],
        });
        expect(pc.plugin, 'packages/generators/*');
        expect(pc.include, ['app_*']);
        expect(pc.exclude, ['*_test']);
        expect(pc.options, isEmpty);
        expect(pc.capabilities, isEmpty);
        expect(pc.priority, 0);
      },
    );

    test('unknown capability strings are ignored gracefully', () {
      final pc = PluginConfig.fromYaml({
        'plugin': 'my_plugin',
        'capabilities': ['inference', 'unknown_cap'],
      });
      expect(pc.capabilities, contains(PluginCapability.inference));
      expect(pc.capabilities, hasLength(1));
    });
  });

  group('ConformanceRuleConfig', () {
    test('fromYaml parses all fields', () {
      final rule = ConformanceRuleConfig.fromYaml({
        'id': 'my-rule',
        'type': 'require-target',
        'options': {'target': 'test'},
      });
      expect(rule.id, 'my-rule');
      expect(rule.type, 'require-target');
      expect(rule.options['target'], 'test');
    });

    test('fromYaml defaults id from type', () {
      final rule = ConformanceRuleConfig.fromYaml({'type': 'require-tags'});
      expect(rule.id, 'require-tags');
    });

    test('fromYaml defaults options to empty map', () {
      final rule = ConformanceRuleConfig.fromYaml({
        'id': 'x',
        'type': 'require-tags',
      });
      expect(rule.options, isEmpty);
    });
  });

  group('ReleaseConfig', () {
    test('fromYaml parses preserveMatchingDependencyRanges', () {
      final config = ReleaseConfig.fromYaml({
        'preserveMatchingDependencyRanges': true,
      });
      expect(config.preserveMatchingDependencyRanges, isTrue);
    });

    test('preserveMatchingDependencyRanges defaults to false', () {
      final config = ReleaseConfig.fromYaml({});
      expect(config.preserveMatchingDependencyRanges, isFalse);
    });

    test('fromYaml parses manifestRootsToUpdate', () {
      final config = ReleaseConfig.fromYaml({
        'manifestRootsToUpdate': ['package.json', 'version.txt'],
      });
      expect(config.manifestRootsToUpdate, ['package.json', 'version.txt']);
    });

    test('manifestRootsToUpdate defaults to empty', () {
      final config = ReleaseConfig.fromYaml({});
      expect(config.manifestRootsToUpdate, isEmpty);
    });

    test('fromYaml parses global versionActions', () {
      final config = ReleaseConfig.fromYaml({
        'versionActions': [
          {'command': 'dart run build_runner build', 'phase': 'pre'},
          {'command': 'dart run update_changelog'},
        ],
      });
      expect(config.versionActions, hasLength(2));
      expect(config.versionActions[0].command, 'dart run build_runner build');
      expect(config.versionActions[0].phase, 'pre');
      expect(config.versionActions[1].phase, 'post'); // default
    });

    test('fromYaml parses group-level versionActions', () {
      final config = ReleaseConfig.fromYaml({
        'groups': {
          'libs': {
            'projects': ['pkg_a', 'pkg_b'],
            'versionActions': [
              {'command': 'update-changelog.sh', 'phase': 'post'},
            ],
          },
        },
      });
      final group = config.groups['libs']!;
      expect(group.versionActions, hasLength(1));
      expect(group.versionActions[0].command, 'update-changelog.sh');
    });
  });
}
