---
title: Generate Code
description: Scaffold new packages, apps, and plugins from built-in or custom generators with interactive prompts and template engines.
---

# Generate Code

Consistency matters in a monorepo. When every package follows the same structure — same directory layout, same config files, same test setup — developers can jump between packages without friction.

fx includes a code generation framework that scaffolds new projects with consistent structure and configuration. Instead of copying an existing package and renaming everything manually, run a single command.

## Discovering Available Generators

```text
$ fx generate --list

  Available generators:

  Project Generators:
    dart_package         Scaffold a pure Dart package
    dart_cli             Scaffold a Dart CLI application
    flutter_package      Scaffold a Flutter package
    flutter_app          Scaffold a Flutter application

  Workspace Generators:
    add_dependency       Add a dependency between workspace projects
    rename_package       Rename a package and update all references
    move_package         Move a package to a different directory

  Custom Generators:
    (none configured — see docs for creating custom generators)
```

## Project Generators

### Dart Package

```text
$ fx generate dart_package my_utils

  Creating dart_package "my_utils"...

  CREATE packages/my_utils/pubspec.yaml
  CREATE packages/my_utils/lib/my_utils.dart
  CREATE packages/my_utils/lib/src/.gitkeep
  CREATE packages/my_utils/test/my_utils_test.dart
  CREATE packages/my_utils/analysis_options.yaml

  Successfully created "my_utils" at packages/my_utils
```

Generated structure:

```text
packages/my_utils/
  lib/
    my_utils.dart           # Barrel file exporting public API
    src/
      .gitkeep
  test/
    my_utils_test.dart      # Starter test file
  pubspec.yaml              # Package manifest with workspace config
  analysis_options.yaml     # Inherits from workspace analysis options
```

### Dart CLI Application

```text
$ fx generate dart_cli my_tool --directory apps/my_tool

  CREATE apps/my_tool/pubspec.yaml
  CREATE apps/my_tool/bin/my_tool.dart
  CREATE apps/my_tool/lib/my_tool.dart
  CREATE apps/my_tool/lib/src/runner.dart
  CREATE apps/my_tool/test/runner_test.dart
  CREATE apps/my_tool/analysis_options.yaml
```

### Flutter Package

```text
$ fx generate flutter_package ui_components
```

### Flutter Application

```text
$ fx generate flutter_app my_app --directory apps/my_app

  CREATE apps/my_app/pubspec.yaml
  CREATE apps/my_app/lib/main.dart
  CREATE apps/my_app/lib/app.dart
  CREATE apps/my_app/test/widget_test.dart
  CREATE apps/my_app/analysis_options.yaml
```

## Workspace Generators

Workspace generators modify existing projects rather than creating new ones. They handle refactoring operations that would be tedious and error-prone to do manually.

### Add a Dependency

```text
$ fx generate add_dependency --source my_app --target shared

  Updated apps/my_app/pubspec.yaml:
    + shared: path: ../../packages/shared

  Project graph updated.
```

### Rename a Package

```text
$ fx generate rename_package --from old_name --to new_name

  Renamed package: old_name → new_name

  Updated files:
    packages/new_name/pubspec.yaml       (name field)
    packages/app/pubspec.yaml            (dependency reference)
    packages/app/lib/src/service.dart    (import statement)
    packages/models/pubspec.yaml         (dependency reference)

  4 files updated across 3 projects.
```

### Move a Package

```text
$ fx generate move_package --project my_utils --to libs/utils

  Moved packages/my_utils → libs/utils

  Updated path dependencies in 2 projects.
```

## Interactive Mode

Generators support interactive prompts for customization:

```text
$ fx generate dart_package my_utils -i

  ? Package description: Shared utility functions
  ? Include test directory? Yes
  ? Add to existing project as dependency? No
  ? Tags (comma-separated): shared, utility

  Creating dart_package "my_utils"...
  Successfully created "my_utils" at packages/my_utils
```

Skip prompts in CI with `--no-interactive`:

```text
fx generate dart_package my_utils --no-interactive
```

## Dry Run

Preview what would be generated without writing any files:

```text
$ fx generate dart_package my_utils --dry-run

  DRY RUN — no files will be written

  Would create:
    packages/my_utils/pubspec.yaml
    packages/my_utils/lib/my_utils.dart
    packages/my_utils/lib/src/.gitkeep
    packages/my_utils/test/my_utils_test.dart
    packages/my_utils/analysis_options.yaml

  5 files would be created.
```

## Generator Options

```text
fx generate <generator> <name> [options]

--directory, -d       Output directory (default: packages/<name>)
--dry-run             Preview without writing files
--list                List all available generators
--interactive, -i     Prompt for generator options
--no-interactive      Skip prompts (CI mode)
--verbose             Show template variable expansion
```

## Template Engine

Generated files use Mustache-style variable substitution. When fx creates a file from a generator template, it replaces `{{key}}` placeholders with values from the generator context:

```text
name: {{name}}
description: {{description}}
version: {{version}}
environment:
  sdk: {{sdkConstraint}}
```

Variables are populated from:
1. **Command arguments** — name, directory
2. **Interactive prompts** — description, tags, etc.
3. **Generator defaults** — from workspace config
4. **Computed values** — SDK version, current date, etc.

## Generator Defaults

Set default values for generator prompts in your workspace config to enforce team standards:

```yaml
fx:
  generatorDefaults:
    dart_package:
      description: "A workspace package"
      sdkConstraint: "^3.5.0"
    flutter_app:
      minSdkVersion: 21
      targetSdkVersion: 34
```

When defaults are configured, interactive prompts pre-fill with these values, and `--no-interactive` mode uses them automatically.

## Sync Generators

Some generators are designed to run repeatedly, keeping generated code in sync with workspace configuration. This is useful for maintaining consistency as your workspace evolves.

```text
$ fx sync

  Running sync generators...

  ✓ Updated 3 analysis_options.yaml files
  ✓ Updated 2 .gitignore files
  ✓ Regenerated barrel files for 5 packages

  Sync complete.
```

### Check Mode for CI

Verify that sync generators don't produce changes (useful in CI to catch uncommitted generated code):

```text
$ fx check:sync

  Checking sync generators...

  ✗ 2 files would change:
    packages/core/lib/core.dart (barrel file out of date)
    packages/utils/analysis_options.yaml (missing new rule)

  Run "fx sync" to apply changes.
  Exit code: 1
```

### Configure Sync

```yaml
fx:
  syncConfig:
    applyChanges: true        # Auto-apply changes (vs. report only)
    disabledGenerators:
      - legacy_generator      # Skip specific generators
```

## Custom Generators

Create your own generators to enforce team-specific patterns. Define a generator class with templates, prompts, and file generation logic:

```dart
class FeaturePackageGenerator extends Generator {
  @override
  String get name => 'feature_package';

  @override
  String get description => 'Scaffold a feature package with BLoC pattern';

  @override
  List<GeneratorPrompt> get prompts => [
    GeneratorPrompt(
      name: 'description',
      message: 'Feature description:',
      type: PromptType.text,
    ),
  ];

  @override
  Future<void> generate(GeneratorContext context) async {
    // Generate files using context.name, context.directory, etc.
  }
}
```

See [Custom Generators](/extending/custom-generators) for the complete guide.

## Learn More

- [Custom Generators](/extending/custom-generators) — Build your own generators
- [Types of Configuration](/concepts/configuration) — Where generator defaults come from
- [Plugins](/concepts/plugins) — How generators fit into the plugin system
