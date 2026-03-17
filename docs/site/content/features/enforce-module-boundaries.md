---
title: Enforce Module Boundaries
description: Use tags and dependency rules to enforce architectural constraints and prevent unintended coupling between projects.
---

# Enforce Module Boundaries

As monorepos grow, teams discover that "everything can depend on everything" leads to architectural chaos. A shared utility starts importing an app-specific model. A feature package depends on another feature's internals. Before long, changing one package requires touching half the workspace.

fx prevents this with **module boundary rules** — tag-based constraints that define which projects can depend on which others. Violations are caught by `fx lint`, giving you the same confidence as compile-time checks but for your architecture.

## Why Module Boundaries Matter

Without boundaries:

```text
shared → app          # Shared depends on app? Now shared can't be reused
feature_a → feature_b # Features coupled? Can't deploy independently
ui → data_layer       # UI bypasses domain? Business logic leaks
```

With boundaries:

```text
$ fx lint

  ✗ Module boundary violation:
    "shared" (tag: shared) depends on "app" (tag: app)
    Rule: Projects tagged "shared" cannot depend on tags: [app, feature]

  ✗ Module boundary violation:
    "feature_auth" (tag: feature) depends on "feature_profile" (tag: feature)
    Rule: Projects tagged "feature" cannot depend on tags: [feature]

  2 violations found. Fix dependency issues before proceeding.
```

These violations are caught **before** they reach production.

## How It Works

Module boundaries require three things:

### 1. Tag Projects

Assign tags to each project in its `pubspec.yaml`:

```yaml
# packages/shared/pubspec.yaml
name: shared
fx:
  tags:
    - shared
```

```yaml
# packages/models/pubspec.yaml
name: models
fx:
  tags:
    - core
    - data
```

```yaml
# apps/mobile/pubspec.yaml
name: mobile
fx:
  tags:
    - app
    - mobile
```

Tags are free-form strings. Use them to categorize projects by layer, scope, team, or any other dimension.

### 2. Define Rules

In your root `pubspec.yaml` or `fx.yaml`, declare which tags can depend on which others:

```yaml
fx:
  moduleBoundaries:
    - sourceTag: app
      allowedTags:
        - feature
        - core
        - shared
    - sourceTag: feature
      allowedTags:
        - core
        - shared
      deniedTags:
        - app
        - feature       # Features can't depend on each other
    - sourceTag: core
      allowedTags:
        - shared
    - sourceTag: shared
      deniedTags:
        - app
        - feature
        - core
```

### 3. Enforce

```text
$ fx lint

  Checking module boundaries...
  ✓ 24 dependency edges validated
  ✓ 0 violations found
```

## Rule Types

Each rule applies to projects that have the `sourceTag`. Two constraint types are available:

| Field | Meaning | When to Use |
|-------|---------|-------------|
| `allowedTags` | Can **only** depend on projects with these tags | Strict allowlisting — safer, recommended |
| `deniedTags` | **Cannot** depend on projects with these tags | Flexible denylisting — less restrictive |

You can use either or both in the same rule:

```yaml
- sourceTag: feature
  allowedTags: [core, shared]     # Allowlist: only these
  deniedTags: [feature]           # Additionally deny: no feature-to-feature
```

When both are specified, a dependency must satisfy **both** constraints — it must be in the allowed list AND not in the denied list.

### Multiple Tags on a Project

A project can have multiple tags. A dependency is allowed if **any** of the target project's tags satisfy the rule:

```yaml
# If models has tags: [core, data]
# And the rule allows "core" but not "data"
# The dependency is ALLOWED because "core" matches
```

## Wildcard Tags

Tags support glob-style matching with `*`:

```yaml
fx:
  moduleBoundaries:
    - sourceTag: "feature-*"          # Matches feature-auth, feature-profile, etc.
      allowedTags:
        - shared
        - "core-*"                    # Matches core-models, core-utils, etc.
        - "util-*"
      deniedTags:
        - "feature-*"                 # No feature can depend on another feature
```

This scales well in large workspaces where enumerating every tag would be impractical.

## Architecture Patterns

### Layered Architecture

The classic layers: presentation depends on domain, domain depends on data, each layer only reaches down.

```yaml
fx:
  moduleBoundaries:
    - sourceTag: presentation
      allowedTags: [domain, shared]
    - sourceTag: domain
      allowedTags: [data, shared]
    - sourceTag: data
      allowedTags: [shared]
    - sourceTag: shared
      deniedTags: [presentation, domain, data]
```

```text
presentation (UI, widgets)
      ↓
domain (business logic, use cases)
      ↓
data (repositories, data sources)
      ↓
shared (models, utilities)
```

### Feature-Based Architecture

Each feature is isolated. Features communicate through shared abstractions, not direct dependencies.

```yaml
fx:
  moduleBoundaries:
    - sourceTag: feature
      allowedTags: [shared, core]
      deniedTags: [feature]         # No feature-to-feature dependencies
    - sourceTag: core
      allowedTags: [shared]
      deniedTags: [feature]
    - sourceTag: shared
      deniedTags: [feature, core]
```

```text
feature-auth    feature-profile    feature-settings
     ↓               ↓                   ↓
     └───────── core (shared logic) ─────┘
                      ↓
                   shared (models, utils)
```

### Layered + Feature Hybrid

Combine both approaches for large applications:

```yaml
fx:
  moduleBoundaries:
    - sourceTag: app
      allowedTags: [feature, core, shared]
    - sourceTag: "feature-*"
      allowedTags: [core, shared]
      deniedTags: ["feature-*"]
    - sourceTag: core
      allowedTags: [shared]
    - sourceTag: shared
      deniedTags: [app, "feature-*", core]
```

### Multi-Team Boundaries

Prevent teams from accidentally depending on each other's internal packages:

```yaml
fx:
  moduleBoundaries:
    - sourceTag: "team-payments"
      allowedTags: [public-api, shared]
      deniedTags: ["team-*"]
    - sourceTag: "team-identity"
      allowedTags: [public-api, shared]
      deniedTags: ["team-*"]
    - sourceTag: public-api
      allowedTags: [shared]
```

## CI Integration

Add boundary checking to your CI pipeline:

```yaml
# GitHub Actions
steps:
  - run: fx lint
```

`fx lint` returns a non-zero exit code on violations, failing the CI job. This catches architectural violations in PRs before they're merged.

## Incremental Adoption

You don't have to tag every project at once. Start with the most critical boundaries:

1. **Tag your shared packages** with `shared`
2. **Add one rule**: shared cannot depend on apps
3. **Run `fx lint`** to verify
4. **Expand** to more tags and rules over time

Untagged projects are not subject to any boundary rules, so existing code continues to work while you gradually adopt boundaries.

<Info>
Module boundary enforcement checks every dependency edge in the project graph against the configured rules. Both direct and transitive dependencies are validated, so a violation deep in the graph is still caught.
</Info>

## Troubleshooting

### False Positives

If `fx lint` reports a violation that seems incorrect:

1. Check the project's tags with `fx show <project> --tags`
2. Verify the dependency exists with `fx graph --focus <project>`
3. Review rule ordering — rules are evaluated independently, and a dependency must satisfy all applicable rules

### Missing Violations

If a dependency should be caught but isn't:

1. Ensure the source project has the correct `sourceTag`
2. Check that the target project has the tag you're trying to deny
3. Remember: if a project has multiple tags and **any** tag is allowed, the dependency passes

## Learn More

- [Conformance Rules](/recipes/conformance-rules) — Additional code quality rules beyond dependencies
- [Explore Your Workspace](/features/explore-your-workspace) — Visualize the project graph to understand dependencies
- [Types of Configuration](/concepts/configuration) — Where boundary rules are configured
