---
title: Conformance Rule Handlers
description: Create custom conformance rule handlers to enforce workspace-wide standards beyond the built-in rules.
---

# Conformance Rule Handlers

The built-in conformance rules cover common patterns. But every team has unique standards — maybe you need to enforce README files, minimum test coverage ratios, or consistent dependency versions. Custom handlers let you encode any structural check.

## Creating a Handler

Implement the `ConformanceRuleHandler` interface:

```dart
import 'package:fx_graph/fx_graph.dart';
import 'package:fx_core/fx_core.dart';

class RequireReadmeHandler implements ConformanceRuleHandler {
  @override
  String get type => 'require_readme';

  @override
  List<ConformanceViolation> evaluate(
    List<Project> projects,
    ConformanceRuleConfig config,
  ) {
    final violations = <ConformanceViolation>[];

    for (final project in projects) {
      final readmePath = '${project.path}/README.md';
      if (!File(readmePath).existsSync()) {
        violations.add(ConformanceViolation(
          projectName: project.name,
          ruleId: config.id,
          message: 'Missing README.md in ${project.path}',
        ));
      }
    }

    return violations;
  }
}
```

## Handler Interface

```dart
abstract class ConformanceRuleHandler {
  /// Unique type identifier — must match the `type` field in config
  String get type;

  /// Evaluate the rule against all projects
  List<ConformanceViolation> evaluate(
    List<Project> projects,
    ConformanceRuleConfig config,
  );
}
```

### ConformanceRuleConfig

The config object provides:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique rule ID from configuration |
| `type` | `String` | Handler type (matches your handler) |
| `options` | `Map<String, dynamic>` | Arbitrary options from configuration |

### ConformanceViolation

Each violation returned contains:

| Field | Type | Description |
|-------|------|-------------|
| `projectName` | `String` | The project that violated the rule |
| `ruleId` | `String` | The rule's `id` from config |
| `message` | `String` | Human-readable description |

## Registration

Register the handler in the `ConformanceRegistry`:

```dart
final registry = ConformanceRegistry.withBuiltIns();
registry.register(RequireReadmeHandler());
registry.register(DependencyVersionSyncHandler());
registry.register(MinTestCoverageHandler());
```

## Configuration

Reference the handler type in workspace config:

```yaml
fx:
  conformanceRules:
    - id: readme-required
      type: require_readme

    - id: consistent-versions
      type: dependency_version_sync
      options:
        packages:
          - meta
          - collection
          - equatable

    - id: test-ratio
      type: min_test_coverage
      options:
        minRatio: 0.5    # At least 0.5 test files per source file
```

The `type` field must match the handler's `type` property exactly.

## Built-in Handlers Reference

| Type | Description | Options |
|------|-------------|---------|
| `require-target` | Projects must have a specific target | `target`: target name |
| `require-inputs` | Targets must have `inputs` patterns | — |
| `require-tags` | Projects must have at least one tag | — |
| `ban-dependency` | Ban a specific package dependency | `package`, `message` |
| `max-dependencies` | Limit dependency count per project | `max`: number |
| `naming-convention` | Project names must match regex | `pattern`: regex string |

## Advanced Example: Dependency Version Sync

Ensure all projects use the same version of shared dependencies:

```dart
class DependencyVersionSyncHandler implements ConformanceRuleHandler {
  @override
  String get type => 'dependency_version_sync';

  @override
  List<ConformanceViolation> evaluate(
    List<Project> projects,
    ConformanceRuleConfig config,
  ) {
    final packages = (config.options['packages'] as List?)
        ?.cast<String>() ?? [];
    final violations = <ConformanceViolation>[];

    for (final packageName in packages) {
      final versions = <String, List<String>>{};

      for (final project in projects) {
        final version = project.dependencies[packageName]?.version;
        if (version != null) {
          versions.putIfAbsent(version, () => []).add(project.name);
        }
      }

      if (versions.length > 1) {
        for (final entry in versions.entries) {
          violations.add(ConformanceViolation(
            projectName: entry.value.join(', '),
            ruleId: config.id,
            message:
              '$packageName version mismatch: '
              '${entry.value.join(", ")} use ${entry.key}, '
              'but other projects use different versions',
          ));
        }
      }
    }

    return violations;
  }
}
```

## Enforcement

```text
$ fx lint

  Checking conformance rules...
  ✗ readme-required: "new_package" — Missing README.md
  ✗ consistent-versions: "app, models" — meta version mismatch:
    app, models use ^1.8.0, but utils uses ^1.9.0
  ✓ test-ratio: All projects meet minimum test ratio

  2 conformance violations found.
```

`fx lint` returns a non-zero exit code when violations exist, suitable for CI gates.

## Custom Rule Ideas

| Rule | Description |
|------|-------------|
| `require-readme` | Every project must have a README.md |
| `require-exports` | `lib/<name>.dart` barrel file must exist |
| `max-file-count` | Limit files per project (prevents mega-packages) |
| `dependency-version-sync` | All projects use same version of shared deps |
| `require-description` | pubspec.yaml must have a description |
| `min-test-ratio` | Minimum test file to source file ratio |
| `no-relative-imports` | Forbid relative imports between packages |
| `require-changelog` | CHANGELOG.md must exist and be non-empty |

## Learn More

- [Conformance Rules](/recipes/conformance-rules) — Configure and use rules
- [Plugins](/concepts/plugins) — Plugin architecture overview
- [Enforce Module Boundaries](/features/enforce-module-boundaries) — Tag-based dependency rules
