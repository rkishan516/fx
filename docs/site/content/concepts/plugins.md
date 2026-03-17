---
title: Plugins
description: Extend fx with custom executors, generators, and conformance rules through the plugin architecture.
---

# Plugins

fx has a pluggable architecture with three extension points. Each lets you customize a different part of the system without modifying fx itself.

## Extension Points

| Extension | What It Does | Interface |
|-----------|-------------|-----------|
| Executor plugins | Custom task execution logic | `ExecutorPlugin` |
| Generator plugins | Custom code scaffolding | `Generator` |
| Conformance handlers | Custom code quality rules | `ConformanceRuleHandler` |

## Executor Plugins

Executor plugins replace the default process-based execution with custom logic. Use them when a simple shell command isn't enough — when you need to programmatically analyze output, manage multiple processes, or integrate with external tools.

### Defining an Executor Plugin

```dart
class CustomBuilder extends ExecutorPlugin {
  @override
  String get name => 'custom_builder';

  @override
  String get description => 'Custom build executor with optimization';

  @override
  Future<TaskResult> execute({
    required Project project,
    required Target target,
    required Map<String, dynamic> options,
    required String workspaceRoot,
  }) async {
    final optimize = options['optimize'] as bool? ?? false;

    // Custom build logic
    final result = await runBuildProcess(
      project.path,
      optimize: optimize,
    );

    return TaskResult(
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
    );
  }
}
```

### Using an Executor Plugin

Reference executor plugins with the `plugin:` prefix in your target configuration:

```yaml
fx:
  targets:
    build:
      executor: "plugin:custom_builder"
      options:
        optimize: true
        target: web
```

The `options` map is passed directly to the plugin's `execute` method, giving you full control over plugin behavior per-target.

### Registering Plugins

Plugins are registered in the `ExecutorRegistry`:

```dart
final registry = ExecutorRegistry()
  ..register(CustomBuilder())
  ..register(DockerExecutor())
  ..register(RemoteExecutor());
```

## Generator Plugins

Custom generators scaffold new code into your workspace. They can generate anything — packages, configuration files, test fixtures, documentation stubs.

### Defining a Generator

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
      defaultValue: 'A new feature',
    ),
    GeneratorPrompt(
      name: 'includeTests',
      message: 'Include test directory?',
      type: PromptType.confirm,
      defaultValue: true,
    ),
  ];

  @override
  Future<void> generate(GeneratorContext context) async {
    context.addFile(
      'lib/${context.name}.dart',
      template: '// {{name}} feature barrel file',
    );
    if (context.variables['includeTests'] == true) {
      context.addFile(
        'test/${context.name}_test.dart',
        template: testTemplate,
      );
    }
  }
}
```

### Configuring Generator Paths

```yaml
fx:
  generators:
    - tools/generators          # Directory containing generator classes
    - packages/internal/generators
```

fx discovers generators from these paths at startup.

## Conformance Rule Handlers

Custom conformance rules enforce code quality standards beyond what linters cover. They operate on the project graph and workspace configuration, not individual source files.

### Defining a Handler

```dart
class MaxDependenciesHandler extends ConformanceRuleHandler {
  @override
  String get type => 'max-dependencies';

  @override
  List<ConformanceViolation> check({
    required Project project,
    required Map<String, dynamic> options,
    required ProjectGraph graph,
  }) {
    final maxDeps = options['max'] as int? ?? 5;
    final depCount = graph.dependenciesOf(project.name).length;

    if (depCount > maxDeps) {
      return [
        ConformanceViolation(
          message: '${project.name} has $depCount dependencies (max: $maxDeps)',
          severity: Severity.error,
        ),
      ];
    }
    return [];
  }
}
```

### Using in Configuration

```yaml
fx:
  conformanceRules:
    - id: max-deps
      type: max-dependencies
      options:
        max: 5
    - id: require-tests
      type: require-target
      options:
        target: test
```

## Plugin Scoping

Restrict plugins to specific projects using include/exclude patterns:

```yaml
fx:
  pluginConfigs:
    - plugin: tools/generators/flutter_only
      include:
        - "packages/flutter_*"     # Only Flutter packages
      exclude:
        - "packages/flutter_legacy" # Except legacy
    - plugin: tools/executors/docker_build
      include:
        - "apps/*"                 # Only app projects
```

The `PluginConfig.appliesTo()` method checks whether a plugin applies to a given project, supporting glob patterns for flexible scoping.

## When to Use Plugins vs. Shell Commands

| Scenario | Approach |
|----------|----------|
| Simple command (`dart test`) | String executor |
| Command with flags (`dart test --coverage`) | String executor |
| Complex build logic | Executor plugin |
| Multi-step process management | Executor plugin |
| Custom output parsing | Executor plugin |
| Standard scaffolding | Built-in generator |
| Team-specific patterns | Generator plugin |
| Lint-level checks | `dart analyze` |
| Architectural constraints | Conformance handler |

## Learn More

- [Executor Plugins](/extending/executor-plugins) — Full executor plugin guide
- [Custom Generators](/extending/custom-generators) — Build your own generators
- [Conformance Handlers](/extending/conformance-handlers) — Write custom conformance rules
- [Conformance Rules](/recipes/conformance-rules) — Configure built-in rules
