---
title: .fxignore
description: Exclude files and directories from project discovery.
---

# .fxignore

The `.fxignore` file excludes directories from fx's project discovery, similar to `.gitignore`.

## Location

Place `.fxignore` at the workspace root:

```text
my_workspace/
  .fxignore
  pubspec.yaml
  packages/
```

## Syntax

```text
# Comments start with #
# Blank lines are ignored

# Exclude build artifacts
**/build/
**/.dart_tool/

# Exclude specific packages
packages/legacy_*
packages/deprecated/

# Exclude by path
tools/internal/

# Negation — re-include a previously excluded pattern
!packages/legacy_core
```

## Pattern Matching

| Pattern | Matches |
|---------|---------|
| `*` | Any single path segment |
| `**` | Any number of path segments |
| `?` | Any single character |
| `dir/` | Directory (trailing slash) |
| `!pattern` | Negation (re-include) |

## Rules

- Patterns are matched against paths relative to the workspace root
- The last matching rule wins (like `.gitignore`)
- Comment lines (`#`) and blank lines are ignored
- Negation (`!`) patterns re-include previously excluded paths

## Example

```text
# Ignore generated and build directories
**/build/
**/.dart_tool/
**/coverage/

# Ignore tool packages
tools/

# But keep the generators
!tools/generators/

# Ignore deprecated packages
packages/v1_*
```

## Interaction with Discovery

`.fxignore` is loaded by `ProjectDiscovery` during workspace scanning. Ignored paths are excluded before `pubspec.yaml` files are parsed, so ignored directories incur no parsing overhead.
