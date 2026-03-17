---
title: Executor Plugins
description: Create custom executor plugins for specialized build logic that goes beyond shell commands.
---

# Executor Plugins

String executors (`dart test`, `dart analyze`) handle most tasks. But sometimes you need more:

- **Complex build logic** with multiple steps
- **Conditional execution** based on project configuration
- **Custom output parsing** for specialized reporting
- **Integration with external build systems**

Executor plugins let you write this logic in Dart and integrate it seamlessly with fx's task execution, caching, and reporting.

## Creating an Executor Plugin

Implement the `ExecutorPlugin` interface:

```dart
import 'package:fx_runner/fx_runner.dart';
import 'package:fx_core/fx_core.dart';

class CustomBuilder extends ExecutorPlugin {
  @override
  String get name => 'custom_builder';

  @override
  String get description => 'Custom build with optimization and tree-shaking';

  @override
  Future<TaskResult> execute({
    required Project project,
    required Target target,
    required Map<String, dynamic> options,
    required String workspaceRoot,
  }) async {
    final optimize = options['optimize'] as bool? ?? false;
    final targetPlatform = options['target'] as String? ?? 'native';

    final stopwatch = Stopwatch()..start();
    final stdout = StringBuffer();
    final stderr = StringBuffer();

    try {
      // Step 1: Pre-build validation
      stdout.writeln('Validating ${project.name}...');
      final valid = await _validate(project);
      if (!valid) {
        return TaskResult(
          projectName: project.name,
          targetName: target.name,
          status: TaskStatus.failure,
          exitCode: 1,
          stdout: stdout.toString(),
          stderr: 'Validation failed',
          duration: stopwatch.elapsed,
        );
      }

      // Step 2: Build
      stdout.writeln('Building for $targetPlatform...');
      final buildResult = await _build(
        project, targetPlatform, optimize: optimize,
      );
      stdout.write(buildResult.output);

      // Step 3: Post-build (optional optimization)
      if (optimize) {
        stdout.writeln('Optimizing output...');
        await _optimize(project);
      }

      stopwatch.stop();
      return TaskResult(
        projectName: project.name,
        targetName: target.name,
        status: TaskStatus.success,
        exitCode: 0,
        stdout: stdout.toString(),
        stderr: stderr.toString(),
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TaskResult(
        projectName: project.name,
        targetName: target.name,
        status: TaskStatus.failure,
        exitCode: 1,
        stdout: stdout.toString(),
        stderr: e.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }
}
```

## Registration

Register plugins in the `ExecutorRegistry`:

```dart
final registry = ExecutorRegistry();
registry.register(CustomBuilder());
registry.register(DockerBuildExecutor());
registry.register(CodegenExecutor());
```

## Configuration

Reference plugins using the `plugin:` prefix in target configuration:

```yaml
fx:
  targets:
    build:
      executor: "plugin:custom_builder"
      options:
        optimize: true
        target: web
        outputDir: build/web
```

The `options` map is passed directly to the plugin's `execute` method. You can put any configuration here — it's an opaque map from fx's perspective.

## Plugin Detection

The `ExecutorRegistry` provides utilities for identifying plugin executors:

```dart
ExecutorRegistry.isPluginExecutor('plugin:my_builder');  // true
ExecutorRegistry.isPluginExecutor('dart test');            // false
ExecutorRegistry.extractPluginName('plugin:my_builder');   // 'my_builder'
```

## TaskResult

Plugins must return a `TaskResult` with these fields:

| Field | Type | Description |
|-------|------|-------------|
| `projectName` | `String` | Project that was executed |
| `targetName` | `String` | Target that was executed |
| `status` | `TaskStatus` | `success`, `failure`, `skipped`, `cached` |
| `exitCode` | `int` | Process exit code (0 = success) |
| `stdout` | `String` | Standard output (displayed to user, cached) |
| `stderr` | `String` | Standard error (displayed on failure, cached) |
| `duration` | `Duration` | Execution time |

The `stdout` field is particularly important — it's what gets replayed on cache hits. Include meaningful output so cached replays are informative.

## Caching with Plugins

Plugin executor results are cached just like string executor results. The cache key is computed from the target's `inputs` configuration, not from the plugin logic itself. Ensure your `inputs` patterns cover all files that affect the plugin's output.

```yaml
fx:
  targets:
    build:
      executor: "plugin:custom_builder"
      inputs:
        - lib/**
        - build_config.yaml    # Plugin reads this file
        - env('BUILD_MODE')    # Plugin uses this variable
      outputs:
        - build/**             # Plugin writes here
      cache: true
```

## Use Cases

| Scenario | Why Plugin? |
|----------|-------------|
| Multi-step build (validate → compile → optimize) | Shell command can't express the flow |
| Conditional build based on project type | Needs access to `Project` metadata |
| Custom output parsing/formatting | Needs to process stdout before returning |
| External tool integration (Docker, Terraform) | Needs complex process management |
| Aggregating results from sub-commands | Single command can't capture multiple results |

## Learn More

- [Plugins](/concepts/plugins) — Plugin architecture overview
- [Executors](/concepts/executors) — How executors are resolved
- [Types of Configuration](/concepts/configuration) — Where plugin config lives
