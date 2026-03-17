# Contributing to fx

Thank you for your interest in contributing to fx! This guide will help you get started.

## Development Setup

**Prerequisites:** Dart SDK `^3.11.1`

```bash
git clone https://github.com/rkishan516/fx.git
cd fx
dart pub get
```

## Project Structure

fx is itself a Dart workspace monorepo:

```
packages/
  fx_core/       Core models, workspace loading, plugins, migrations
  fx_graph/      Dependency graph, task graph, conformance rules
  fx_runner/     Task execution engine, process management
  fx_cache/      Computation caching (local + remote)
  fx_generator/  Code generation framework
  fx_cli/        CLI commands, output formatting, daemon
```

## Running Tests

```bash
# All tests (~700)
dart test

# Specific package
dart test packages/fx_core

# Single test file
dart test packages/fx_cli/test/commands/graph_command_test.dart

# Use fx to test itself
dart run packages/fx_cli/bin/fx.dart run-many --target test
```

## Development Workflow

1. **Find or create an issue** describing the change
2. **Write a failing test** before any production code (TDD is mandatory)
3. **Implement the minimal code** to make the test pass
4. **Refactor** while keeping tests green
5. **Run the full test suite** to catch regressions
6. **Submit a pull request** with a clear description

## Code Style

- Follow existing patterns in the codebase
- Snake_case for files, PascalCase for classes, camelCase for methods
- Production files should stay under 300 lines (500 hard limit)
- No external dependencies unless already in pubspec — check before adding
- Use `FxException` hierarchy for errors
- Injectable abstractions for testability (no direct `Process.run` in business logic)

## Testing Guidelines

- **Unit tests** for all business logic, models, and utilities
- **Integration tests** for command-level behavior with temp workspaces
- **Mock external dependencies** — use injectable abstractions (`ProcessStarter`, `GitRunner`, etc.)
- Minimum 80% coverage for new code
- Test files are exempt from the 300-line limit

## Architecture Decisions

- **Composition over inheritance** — prefer small, focused classes
- **Backward compatibility** — new features must not break existing configs
- **Dart-native design** — leverage Dart's workspace feature, pubspec.yaml conventions
- **Plugin extensibility** — new capabilities should be pluggable where possible

## Commit Messages

Use conventional commit format:

```
feat: add continuous task support
fix: resolve daemon double-connection bug
test: add task graph visualization tests
docs: update CLI reference table
```

## Need Help?

- Open an issue for bugs or feature requests
- Check existing tests for usage examples
- Read the [documentation site](https://fx.dev) for concepts and recipes
