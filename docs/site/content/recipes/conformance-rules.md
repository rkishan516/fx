---
title: Conformance Rules
description: Enforce workspace-wide architectural standards with pluggable conformance rules that go beyond linting.
---

# Conformance Rules

Conformance rules are workspace-wide checks that enforce architectural standards across all projects. While `dart analyze` catches code-level issues, conformance rules catch **structural** issues — missing test targets, unnamed projects, banned dependencies, and more.

## How It Looks

```text
$ fx lint

  Checking conformance rules...

  ✗ require-test-target: "legacy_utils" has no "test" target
  ✗ require-tags: "new_package" has no tags assigned
  ✗ ban-dependency: "feature_auth" depends on banned package "http"
    → Use package:dio instead of package:http
  ✓ naming-convention: All 12 projects match pattern ^[a-z][a-z0-9_]*$
  ✓ max-dependencies: All projects have ≤ 10 dependencies

  Module boundaries:
  ✓ 47 dependency edges validated, 0 violations

  3 conformance violations found.
```

## Configuration

```yaml
fx:
  conformanceRules:
    - id: all-projects-have-tests
      type: require-target
      options:
        target: test

    - id: all-targets-have-inputs
      type: require-inputs

    - id: all-projects-tagged
      type: require-tags

    - id: no-http-dependency
      type: ban-dependency
      options:
        package: http
        message: "Use package:dio instead of package:http"

    - id: max-deps
      type: max-dependencies
      options:
        max: 10

    - id: naming
      type: naming-convention
      options:
        pattern: "^[a-z][a-z0-9_]*$"
```

Each rule has:
- **`id`** — A unique identifier for error messages and selective running
- **`type`** — The handler that implements the rule
- **`options`** — Configuration passed to the handler

## Running Conformance Checks

```text
# Run all rules (including module boundaries)
fx lint

# Run specific rules only
fx lint --rules "require-target,naming-convention"

# Verbose output showing all checks
fx lint --verbose
```

`fx lint` returns a non-zero exit code when violations are found, making it suitable for CI gates.

## Built-in Rule Handlers

### require-target

Every project must define or inherit a specific target. Catches projects that were added without proper target setup.

```yaml
- id: all-testable
  type: require-target
  options:
    target: test
```

```text
✗ require-target: "legacy_utils" has no "test" target
  Add a test/ directory or define the target explicitly.
```

### require-inputs

All targets must have `inputs` patterns defined. Prevents overbroad caching where every file change triggers cache misses.

```yaml
- id: explicit-inputs
  type: require-inputs
```

```text
✗ require-inputs: "core:build" has no inputs defined
  Without inputs, all files in the project are hashed, causing frequent cache misses.
```

### require-tags

Every project must have at least one tag assigned. This ensures module boundary rules can apply to all projects.

```yaml
- id: tagged
  type: require-tags
```

```text
✗ require-tags: "new_package" has no tags assigned
  Add tags in packages/new_package/pubspec.yaml under fx.tags
```

### ban-dependency

Projects cannot depend on a specific package. Use this to enforce migration away from deprecated or undesirable packages.

```yaml
- id: no-http
  type: ban-dependency
  options:
    package: http
    message: "Use dio instead — http lacks interceptors and retry support"
```

```text
✗ ban-dependency: "feature_auth" depends on banned package "http"
  → Use dio instead — http lacks interceptors and retry support
```

### max-dependencies

Limits the number of dependencies per project. High dependency counts often indicate a package that's doing too much.

```yaml
- id: bounded-deps
  type: max-dependencies
  options:
    max: 8
```

```text
✗ max-dependencies: "mega_package" has 14 dependencies (max: 8)
  Consider splitting this package into smaller, focused packages.
```

### naming-convention

Project names must match a regex pattern. Enforces consistent naming across the workspace.

```yaml
- id: snake-case
  type: naming-convention
  options:
    pattern: "^[a-z][a-z0-9_]*$"
```

```text
✗ naming-convention: "MyPackage" doesn't match pattern ^[a-z][a-z0-9_]*$
  Use snake_case for package names.
```

## Custom Rule Handlers

When built-in rules aren't enough, implement the `ConformanceRuleHandler` interface:

```dart
class NoCircularImportsHandler implements ConformanceRuleHandler {
  @override
  String get type => 'no-circular-imports';

  @override
  List<ConformanceViolation> evaluate(
    List<Project> projects,
    ConformanceRuleConfig config,
  ) {
    final violations = <ConformanceViolation>[];

    for (final project in projects) {
      final cycles = detectImportCycles(project);
      for (final cycle in cycles) {
        violations.add(ConformanceViolation(
          projectName: project.name,
          ruleId: config.id,
          message: 'Circular import: ${cycle.join(" → ")}',
        ));
      }
    }

    return violations;
  }
}
```

Register the handler:

```dart
final registry = ConformanceRegistry.withBuiltIns();
registry.register(NoCircularImportsHandler());
```

See [Conformance Handlers](/extending/conformance-handlers) for the complete guide.

## Incremental Adoption

You don't need to adopt all rules at once. Start with the most impactful:

1. **`require-tags`** — Enables module boundaries
2. **`ban-dependency`** — Enforce migration policies
3. **`naming-convention`** — Consistency
4. **`require-target`** — Ensure test coverage
5. **`max-dependencies`** — Architecture quality

## Learn More

- [Enforce Module Boundaries](/features/enforce-module-boundaries) — Tag-based dependency rules
- [Conformance Handlers](/extending/conformance-handlers) — Build custom rules
- [CI Setup](/recipes/ci-setup) — Run `fx lint` in CI
