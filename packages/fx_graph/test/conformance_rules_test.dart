import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:test/test.dart';

void main() {
  Project makeProject(
    String name, {
    List<String> tags = const [],
    List<String> deps = const [],
    Map<String, Target> targets = const {},
  }) => Project(
    name: name,
    path: '/ws/packages/$name',
    type: ProjectType.dartPackage,
    dependencies: deps,
    tags: tags,
    targets: targets,
  );

  group('ConformanceEnforcer', () {
    test('returns empty when no rules', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });

    test('require-target detects missing target', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a'), makeProject('b')],
        rules: [
          ConformanceRule(
            id: 'must-have-test',
            type: 'require-target',
            options: {'target': 'test'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, hasLength(2));
      expect(violations.first.ruleId, 'must-have-test');
      expect(violations.first.message, contains('test'));
    });

    test('require-target passes when workspace target exists', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [
          ConformanceRule(
            id: 'must-have-test',
            type: 'require-target',
            options: {'target': 'test'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'test': {'executor': 'dart test'},
          },
        }),
      );
      expect(violations, isEmpty);
    });

    test('require-target passes when project target exists', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [
          makeProject(
            'a',
            targets: {'test': Target(name: 'test', executor: 'dart test')},
          ),
        ],
        rules: [
          ConformanceRule(
            id: 'must-have-test',
            type: 'require-target',
            options: {'target': 'test'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });

    test('require-inputs detects target without inputs', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [
          ConformanceRule(
            id: 'test-needs-inputs',
            type: 'require-inputs',
            options: {'target': 'test'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'test': {'executor': 'dart test'},
          },
        }),
      );
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('input patterns'));
    });

    test('require-inputs passes when inputs defined', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [
          ConformanceRule(
            id: 'test-needs-inputs',
            type: 'require-inputs',
            options: {'target': 'test'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {
            'test': {
              'executor': 'dart test',
              'inputs': ['lib/**', 'test/**'],
            },
          },
        }),
      );
      expect(violations, isEmpty);
    });

    test('require-tags detects untagged project', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [ConformanceRule(id: 'needs-tags', type: 'require-tags')],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('tag'));
    });

    test('require-tags passes when project has tags', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [
          makeProject('a', tags: ['scope:shared']),
        ],
        rules: [ConformanceRule(id: 'needs-tags', type: 'require-tags')],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });

    test('ban-dependency detects banned dep', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [
          makeProject('a', deps: ['bad_pkg']),
        ],
        rules: [
          ConformanceRule(
            id: 'no-bad-pkg',
            type: 'ban-dependency',
            options: {'package': 'bad_pkg'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('bad_pkg'));
    });

    test('ban-dependency passes when dep not present', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [
          makeProject('a', deps: ['good_pkg']),
        ],
        rules: [
          ConformanceRule(
            id: 'no-bad-pkg',
            type: 'ban-dependency',
            options: {'package': 'bad_pkg'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });

    test('ConformanceRule.fromYaml parses correctly', () {
      final rule = ConformanceRule.fromYaml({
        'id': 'my-rule',
        'type': 'require-target',
        'options': {'target': 'test'},
      });
      expect(rule.id, 'my-rule');
      expect(rule.type, 'require-target');
      expect(rule.options['target'], 'test');
    });

    test('unknown rule type is silently ignored', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [ConformanceRule(id: 'x', type: 'does-not-exist')],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });
  });

  group('ConformanceRegistry', () {
    test('withBuiltIns registers all built-in handlers', () {
      final registry = ConformanceRegistry.withBuiltIns();
      expect(registry.get('require-target'), isNotNull);
      expect(registry.get('require-inputs'), isNotNull);
      expect(registry.get('require-tags'), isNotNull);
      expect(registry.get('ban-dependency'), isNotNull);
      expect(registry.get('max-dependencies'), isNotNull);
      expect(registry.get('naming-convention'), isNotNull);
    });

    test('register adds custom handler', () {
      final registry = ConformanceRegistry();
      expect(registry.get('custom'), isNull);

      registry.register(_CustomRuleHandler());
      expect(registry.get('custom'), isNotNull);
    });

    test('register overwrites existing handler', () {
      final registry = ConformanceRegistry.withBuiltIns();
      registry.register(_OverrideRequireTargetHandler());
      expect(
        registry.get('require-target'),
        isA<_OverrideRequireTargetHandler>(),
      );
    });

    test('types returns all registered type names', () {
      final registry = ConformanceRegistry.withBuiltIns();
      expect(
        registry.types,
        containsAll([
          'require-target',
          'require-inputs',
          'require-tags',
          'ban-dependency',
          'max-dependencies',
          'naming-convention',
        ]),
      );
    });

    test('enforce uses custom registry', () {
      final registry = ConformanceRegistry()..register(_AlwaysFailHandler());

      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [ConformanceRule(id: 'fail', type: 'always-fail')],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
        registry: registry,
      );
      expect(violations, hasLength(1));
      expect(violations.first.message, 'Always fails');
    });
  });

  group('MaxDependenciesHandler', () {
    test('detects projects exceeding max dependencies', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [
          makeProject('a', deps: ['b', 'c', 'd']),
        ],
        rules: [
          ConformanceRule(
            id: 'max-deps',
            type: 'max-dependencies',
            options: {'max': 2},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('3 dependencies'));
      expect(violations.first.message, contains('maximum of 2'));
    });

    test('passes when within limit', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [
          makeProject('a', deps: ['b']),
        ],
        rules: [
          ConformanceRule(
            id: 'max-deps',
            type: 'max-dependencies',
            options: {'max': 5},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });

    test('returns empty when max option is not an int', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [
          makeProject('a', deps: ['b']),
        ],
        rules: [
          ConformanceRule(
            id: 'max-deps',
            type: 'max-dependencies',
            options: {'max': 'five'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });
  });

  group('NamingConventionHandler', () {
    test('detects names not matching pattern', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('MyPackage')],
        rules: [
          ConformanceRule(
            id: 'snake-case',
            type: 'naming-convention',
            options: {'pattern': r'^[a-z][a-z0-9_]*$'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('MyPackage'));
      expect(violations.first.message, contains('does not match'));
    });

    test('passes when name matches pattern', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('my_package')],
        rules: [
          ConformanceRule(
            id: 'snake-case',
            type: 'naming-convention',
            options: {'pattern': r'^[a-z][a-z0-9_]*$'},
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });

    test('returns empty when pattern option is missing', () {
      final violations = ConformanceEnforcer.enforce(
        projects: [makeProject('a')],
        rules: [ConformanceRule(id: 'naming', type: 'naming-convention')],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });
  });

  group('enforceWithConfig', () {
    test('disabled rules are skipped', () {
      final violations = ConformanceEnforcer.enforceWithConfig(
        projects: [makeProject('a')],
        rules: [
          ConformanceRuleConfig(
            id: 'tags',
            type: 'require-tags',
            status: ConformanceRuleStatus.disabled,
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, isEmpty);
    });

    test('evaluated rules produce warnings', () {
      final violations = ConformanceEnforcer.enforceWithConfig(
        projects: [makeProject('a')],
        rules: [
          ConformanceRuleConfig(
            id: 'tags',
            type: 'require-tags',
            status: ConformanceRuleStatus.evaluated,
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, hasLength(1));
      expect(violations.first.isWarning, isTrue);
    });

    test('enforced rules produce errors', () {
      final violations = ConformanceEnforcer.enforceWithConfig(
        projects: [makeProject('a')],
        rules: [
          ConformanceRuleConfig(
            id: 'tags',
            type: 'require-tags',
            status: ConformanceRuleStatus.enforced,
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      expect(violations, hasLength(1));
      expect(violations.first.isWarning, isFalse);
    });

    test('project matcher filters projects', () {
      final violations = ConformanceEnforcer.enforceWithConfig(
        projects: [
          makeProject('app_main'),
          makeProject('lib_core'),
          makeProject('app_secondary'),
        ],
        rules: [
          ConformanceRuleConfig(
            id: 'tags',
            type: 'require-tags',
            projects: [
              ConformanceProjectMatcher(
                matcher: 'app_*',
                explanation: 'Only apps need tags',
              ),
            ],
          ),
        ],
        config: FxConfig.fromYaml({
          'packages': ['packages/*'],
          'targets': {},
        }),
      );
      // Only app_main and app_secondary match, lib_core is excluded
      expect(violations, hasLength(2));
      expect(
        violations.map((v) => v.projectName),
        containsAll(['app_main', 'app_secondary']),
      );
    });

    test('project matcher with explanation in fromYaml', () {
      final matcher = ConformanceProjectMatcher.fromYaml({
        'matcher': 'packages/*',
        'explanation': 'Only packages need this rule',
      });
      expect(matcher.matcher, 'packages/*');
      expect(matcher.explanation, 'Only packages need this rule');
      expect(matcher.matches('packages/core'), isTrue);
      expect(matcher.matches('apps/main'), isFalse);
    });

    test('ConformanceRuleConfig.fromYaml parses all fields', () {
      final config = ConformanceRuleConfig.fromYaml({
        'id': 'my-rule',
        'type': 'require-tags',
        'status': 'evaluated',
        'explanation': 'All projects need tags',
        'projects': [
          'app_*',
          {'matcher': 'lib_*', 'explanation': 'Libraries too'},
        ],
        'options': {'foo': 'bar'},
      });
      expect(config.id, 'my-rule');
      expect(config.status, ConformanceRuleStatus.evaluated);
      expect(config.explanation, 'All projects need tags');
      expect(config.projects, hasLength(2));
      expect(config.projects[0].matcher, 'app_*');
      expect(config.projects[1].explanation, 'Libraries too');
    });
  });

  group('EnsureOwnersHandler', () {
    test('ensure-owners registered in withBuiltIns', () {
      final registry = ConformanceRegistry.withBuiltIns();
      expect(registry.get('ensure-owners'), isNotNull);
    });
  });
}

class _CustomRuleHandler extends ConformanceRuleHandler {
  @override
  String get type => 'custom';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) => [];
}

class _OverrideRequireTargetHandler extends ConformanceRuleHandler {
  @override
  String get type => 'require-target';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) => [];
}

class _AlwaysFailHandler extends ConformanceRuleHandler {
  @override
  String get type => 'always-fail';

  @override
  List<ConformanceViolation> evaluate({
    required List<Project> projects,
    required ConformanceRule rule,
    required FxConfig config,
  }) => projects
      .map(
        (p) => ConformanceViolation(
          projectName: p.name,
          ruleId: rule.id,
          message: 'Always fails',
        ),
      )
      .toList();
}
