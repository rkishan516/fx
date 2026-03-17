---
title: Custom Generators
description: Create custom code generators to scaffold projects with your team's conventions and patterns.
---

# Custom Generators

fx's built-in generators cover common patterns (Dart packages, Flutter apps). But every team has their own conventions — BLoC architecture, specific folder structures, common dependencies, README templates. Custom generators let you encode these patterns into reusable scaffolding.

## Creating a Generator

Extend the `Generator` base class:

```dart
import 'package:fx_generator/fx_generator.dart';

class ServiceGenerator extends Generator {
  @override
  String get name => 'service';

  @override
  String get description => 'Generate a service package with DI setup';

  @override
  List<GeneratorPrompt> get prompts => [
    GeneratorPrompt(
      name: 'description',
      message: 'Service description:',
      type: PromptType.text,
      defaultValue: 'A service package',
    ),
    GeneratorPrompt(
      name: 'includeApi',
      message: 'Include API client?',
      type: PromptType.confirm,
    ),
    GeneratorPrompt(
      name: 'httpPackage',
      message: 'HTTP package:',
      type: PromptType.select,
      options: ['dio', 'http', 'chopper'],
      defaultValue: 'dio',
    ),
  ];

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorContext context,
  ) async {
    final files = <GeneratedFile>[
      GeneratedFile(
        relativePath: 'lib/${context.projectName}.dart',
        content: "library ${context.projectName};",
      ),
      GeneratedFile(
        relativePath: 'lib/src/service.dart',
        content: _serviceTemplate(context),
      ),
      GeneratedFile(
        relativePath: 'pubspec.yaml',
        content: _pubspecTemplate(context),
      ),
      GeneratedFile(
        relativePath: 'analysis_options.yaml',
        content: 'include: package:lints/recommended.yaml\n',
      ),
    ];

    if (context.variables['includeApi'] == true) {
      files.add(GeneratedFile(
        relativePath: 'lib/src/api_client.dart',
        content: _apiClientTemplate(context),
      ));
    }

    return files;
  }

  String _serviceTemplate(GeneratorContext context) {
    final className = _classify(context.projectName);
    return '''
/// ${context.variables['description']}
class ${className}Service {
  const ${className}Service();
}
''';
  }

  String _pubspecTemplate(GeneratorContext context) {
    return '''
name: ${context.projectName}
description: ${context.variables['description']}
version: 0.1.0
environment:
  sdk: ^3.5.0
''';
  }

  String _classify(String input) {
    return input.split('_').map((s) =>
      s[0].toUpperCase() + s.substring(1)
    ).join();
  }
}
```

## Registering Generators

### Via Configuration (Recommended)

Point fx to directories containing generator code:

```yaml
fx:
  generators:
    - tools/generators
    - packages/internal/generators
```

The `GeneratorPluginLoader` discovers generators from these paths at startup.

### Via Code

Register directly in the `GeneratorRegistry`:

```dart
final registry = GeneratorRegistry.withBuiltIns();
registry.register(ServiceGenerator());
registry.register(FeatureModuleGenerator());
```

## Using Your Generator

```text
$ fx generate service auth_service

  ? Service description: Authentication and session management
  ? Include API client? Yes
  ? HTTP package: dio

  CREATE packages/auth_service/pubspec.yaml
  CREATE packages/auth_service/lib/auth_service.dart
  CREATE packages/auth_service/lib/src/service.dart
  CREATE packages/auth_service/lib/src/api_client.dart
  CREATE packages/auth_service/analysis_options.yaml

  Successfully created "auth_service" at packages/auth_service
```

## Generator Prompts

Prompts let users customize generated output interactively:

| Type | Description | Example |
|------|-------------|---------|
| `PromptType.text` | Free-form text input | Package description |
| `PromptType.confirm` | Yes/no boolean | Include test directory? |
| `PromptType.select` | Choose from options | HTTP package: dio/http/chopper |
| `PromptType.multiSelect` | Choose multiple | Features: auth, logging, caching |

### Prompt Properties

```dart
GeneratorPrompt(
  name: 'myOption',         // Variable name in context
  message: 'Question?',     // Displayed to user
  type: PromptType.text,    // Input type
  defaultValue: 'default',  // Pre-filled value
  options: ['a', 'b'],      // For select/multiSelect
  validator: (v) => v.isNotEmpty ? null : 'Required',
)
```

## Generator Context

The `GeneratorContext` provides everything your generator needs:

| Field | Type | Description |
|-------|------|-------------|
| `projectName` | `String` | Package name from CLI argument |
| `outputDirectory` | `String` | Target directory path |
| `variables` | `Map<String, dynamic>` | All prompt responses and defaults |
| `workspaceRoot` | `String` | Workspace root directory |

## Template Engine

For string templates, use the `TemplateEngine` for Mustache-style substitution:

```dart
final engine = TemplateEngine();
final output = engine.render(
  'name: {{name}}\ndescription: {{description}}\nversion: {{version}}',
  {
    'name': context.projectName,
    'description': context.variables['description'],
    'version': '0.1.0',
  },
);
```

Supported syntax:
- `{{variable}}` — Simple substitution
- `{{#condition}}...{{/condition}}` — Conditional sections
- `{{^condition}}...{{/condition}}` — Inverted conditionals (render if false)

## Generator Defaults

Set default values in workspace config so teams don't need to answer prompts repeatedly:

```yaml
fx:
  generatorDefaults:
    service:
      description: "A workspace service"
      includeApi: true
      httpPackage: dio
    feature_module:
      stateManagement: bloc
```

Defaults are used:
- As pre-filled values in interactive mode
- As actual values in `--no-interactive` mode (CI)

## Dry Run

Preview what would be generated without writing any files:

```text
$ fx generate service auth_service --dry-run

  DRY RUN — no files will be written

  Would create:
    packages/auth_service/pubspec.yaml
    packages/auth_service/lib/auth_service.dart
    packages/auth_service/lib/src/service.dart
    packages/auth_service/analysis_options.yaml

  4 files would be created.
```

## Interactive vs. Non-Interactive

```text
# Interactive — prompts for each option
fx generate service auth_service --interactive

# Non-interactive — uses defaults (CI mode)
fx generate service auth_service --no-interactive
```

In CI, always use `--no-interactive` with `generatorDefaults` configured to ensure deterministic generation.

## Learn More

- [Generate Code](/features/generate-code) — User-facing generation guide
- [Plugins](/concepts/plugins) — How generators fit into the plugin system
