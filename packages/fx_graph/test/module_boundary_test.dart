import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:test/test.dart';

void main() {
  group('ModuleBoundaryEnforcer', () {
    test('returns empty list when no rules configured', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['core'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'core',
          path: '/core',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:core'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: [],
      );

      expect(violations, isEmpty);
    });

    test('detects violation when source depends on disallowed tag', () {
      final projects = [
        Project(
          name: 'core',
          path: '/core',
          type: ProjectType.dartPackage,
          dependencies: ['app'],
          targets: {},
          tags: ['scope:core'],
        ),
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:app'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(sourceTag: 'scope:core', deniedTags: ['scope:app']),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(1));
      expect(violations[0].sourceProject, 'core');
      expect(violations[0].targetProject, 'app');
    });

    test('detects violation when dependency tag not in allowed list', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['secret'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'secret',
          path: '/secret',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:internal'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: 'scope:app',
          allowedTags: ['scope:shared', 'scope:core'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(1));
      expect(violations[0].sourceProject, 'app');
      expect(violations[0].targetProject, 'secret');
    });

    test('passes when dependency tag is in allowed list', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['core'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'core',
          path: '/core',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:core'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(sourceTag: 'scope:app', allowedTags: ['scope:core']),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, isEmpty);
    });

    test('wildcard source tag matches all projects', () {
      final projects = [
        Project(
          name: 'a',
          path: '/a',
          type: ProjectType.dartPackage,
          dependencies: ['b'],
          targets: {},
          tags: ['anything'],
        ),
        Project(
          name: 'b',
          path: '/b',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['forbidden'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(sourceTag: '*', deniedTags: ['forbidden']),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(1));
    });

    test('regex tag pattern matches projects', () {
      final projects = [
        Project(
          name: 'feature_auth',
          path: '/feature_auth',
          type: ProjectType.dartPackage,
          dependencies: ['core_db'],
          targets: {},
          tags: ['scope:feature', 'type:ui'],
        ),
        Project(
          name: 'core_db',
          path: '/core_db',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:core', 'type:data'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: '/scope:feature/',
          deniedTags: ['/type:data/'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(1));
      expect(violations[0].sourceProject, 'feature_auth');
    });

    test('glob tag pattern matches projects', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['internal_secret'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'internal_secret',
          path: '/internal_secret',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:internal'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: 'scope:*',
          deniedTags: ['scope:internal'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(1));
      expect(violations[0].sourceProject, 'app');
    });

    test('glob allowed tags match correctly', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['shared_utils'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'shared_utils',
          path: '/shared_utils',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:shared'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: 'scope:app',
          allowedTags: ['scope:shared*'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, isEmpty);
    });

    test('allSourceTags requires all tags to match', () {
      final projects = [
        Project(
          name: 'feature_ui',
          path: '/feature_ui',
          type: ProjectType.dartPackage,
          dependencies: ['core'],
          targets: {},
          tags: ['scope:feature', 'type:ui'],
        ),
        Project(
          name: 'feature_data',
          path: '/feature_data',
          type: ProjectType.dartPackage,
          dependencies: ['core'],
          targets: {},
          tags: ['scope:feature', 'type:data'],
        ),
        Project(
          name: 'core',
          path: '/core',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:core'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: '*',
          allSourceTags: ['scope:feature', 'type:ui'],
          deniedTags: ['scope:core'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      // Only feature_ui matches both tags, feature_data has type:data
      expect(violations, hasLength(1));
      expect(violations[0].sourceProject, 'feature_ui');
    });

    test('bannedExternalImports flags banned external dependencies', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['http', 'core'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'core',
          path: '/core',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:core'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: 'scope:app',
          bannedExternalImports: ['http', 'dio'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(1));
      expect(violations[0].targetProject, 'http');
      expect(violations[0].rule, contains('banned'));
    });

    test('allowedExternalImports flags non-allowed external deps', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['http', 'path', 'core'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'core',
          path: '/core',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:core'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: 'scope:app',
          allowedExternalImports: ['path'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      // 'http' is not in allowed list, 'path' is allowed, 'core' is workspace
      expect(violations, hasLength(1));
      expect(violations[0].targetProject, 'http');
      expect(violations[0].rule, contains('not in the allowed list'));
    });

    test('enforceBuildableLibDependency flags non-buildable deps', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['utils'],
          targets: {
            'build': const Target(name: 'build', executor: 'dart compile'),
          },
          tags: ['scope:app'],
        ),
        Project(
          name: 'utils',
          path: '/utils',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:lib'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(sourceTag: '*', enforceBuildableLibDependency: true),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(1));
      expect(violations[0].rule, contains('non-buildable'));
    });

    test('allowCircularSelfDependency skips self-imports', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['app'],
          targets: {},
          tags: ['scope:app'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: '*',
          deniedTags: ['scope:app'],
          allowCircularSelfDependency: true,
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, isEmpty);
    });

    test('bannedExternalImports with glob pattern', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['firebase_core', 'firebase_auth', 'path'],
          targets: {},
          tags: ['scope:app'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: '*',
          bannedExternalImports: ['firebase_*'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, hasLength(2));
      expect(
        violations.map((v) => v.targetProject),
        containsAll(['firebase_core', 'firebase_auth']),
      );
    });

    test('rule does not apply when source tag does not match', () {
      final projects = [
        Project(
          name: 'app',
          path: '/app',
          type: ProjectType.dartPackage,
          dependencies: ['core'],
          targets: {},
          tags: ['scope:app'],
        ),
        Project(
          name: 'core',
          path: '/core',
          type: ProjectType.dartPackage,
          dependencies: [],
          targets: {},
          tags: ['scope:core'],
        ),
      ];

      final rules = [
        ModuleBoundaryRule(
          sourceTag: 'scope:lib', // doesn't match 'app'
          deniedTags: ['scope:core'],
        ),
      ];

      final violations = ModuleBoundaryEnforcer.enforce(
        projects: projects,
        rules: rules,
      );

      expect(violations, isEmpty);
    });
  });
}
