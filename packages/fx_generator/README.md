# fx_generator

Code generation framework for the fx monorepo tool.

## Overview

Scaffolds new apps, packages, and plugins using built-in or custom generators. Includes a template engine for variable substitution.

## Built-in Generators

| Generator | Description |
|-----------|-------------|
| `dart_package` | Pure Dart package with lib, test, pubspec, analysis_options |
| `dart_cli` | Dart CLI application with bin entry point |
| `flutter_package` | Flutter package with Flutter SDK dependency |
| `flutter_app` | Flutter application with Material app scaffold |

## Key Classes

| Class | Description |
|-------|-------------|
| `Generator` | Base class for all generators |
| `GeneratorRegistry` | Registry of available generators; `withBuiltIns()` includes the 4 defaults |
| `TemplateEngine` | Mustache-style `{{variable}}` substitution engine |
| `GeneratorPluginLoader` | Loads custom generators from workspace plugins |

## Usage

```dart
import 'package:fx_generator/fx_generator.dart';

final registry = GeneratorRegistry.withBuiltIns();
final generator = registry.get('dart_package');
await generator.generate(
  name: 'my_utils',
  outputDir: 'packages/my_utils',
);
```
