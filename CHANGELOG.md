# Changelog

## 0.1.0

### Core

- Workspace management with `fx init` — scaffold a new Dart/Flutter monorepo
- Project model with tags, implicit dependencies, and named inputs
- Workspace configuration via `fx:` key in root `pubspec.yaml`
- `.fxignore` support for excluding files from change detection
- Environment variable helpers and CI provider auto-detection (GitHub Actions, GitLab CI, CircleCI, Travis, Jenkins, Buildkite, CodeBuild, Azure Pipelines, Bitbucket)

### Task Orchestration

- `fx run <project> <target>` — run a target on a single project
- `fx run-many --target <t>` — run across all projects with topological ordering
- `fx affected --target <t> --base <ref>` — run only on projects affected by git changes
- `fx exec -- <cmd>` — run an arbitrary shell command across all projects
- Parallel execution with configurable concurrency (`--parallel`)
- Continuous task support for dev servers (`continuous: true`)
- Task pipeline configuration with `dependsOn` chains
- Batch execution grouping for efficient multi-project runs

### Caching

- Local computation caching with SHA-256 input hashing
- Pluggable remote cache stores: S3, GCS, Azure Blob, HTTP, filesystem
- `fx cache status` and `fx cache clear` commands
- Graph cache for incremental dependency tracking

### Dependency Graph

- `fx graph` with text, JSON, DOT, and web output formats
- Task-level graph visualization with `--tasks`
- Implicit dependency detection via import analysis (`--detect-implicit`)
- Cycle detection with detailed error reporting

### Code Generation

- Built-in generators: `dart_package`, `dart_cli`, `flutter_package`, `flutter_app`, workspace
- Interactive prompts for missing generator parameters
- Custom generator plugins via `generators:` config
- Template engine with variable substitution

### Module Boundaries & Conformance

- `fx lint` — enforce architectural constraints
- Built-in rules: `require-target`, `require-inputs`, `require-tags`, `ban-dependency`, `max-dependencies`, `naming-convention`
- Custom conformance rule plugins

### Plugin System

- Plugin hooks for project inference, dependency inference, and custom executors
- Executor plugin registry for custom build tools
- Generator plugin loader for third-party generators
- `fx plugin list` and `fx add <plugin>` commands

### Watch Mode

- `fx watch --target <t>` — re-run targets on source file changes
- Project filtering with `--projects`

### Background Daemon

- `fx daemon start|stop|graph` — persistent background process
- In-memory project graph for instant queries
- Incremental updates via git-based change detection

### Migration Framework

- `fx migrate --from-melos` — convert from melos workspaces
- Plugin version migrations with `--from`/`--to`
- Two-phase prepare/execute with `--dry-run` preview
- `fx migrate --list` to show available migrations

### MCP Server & AI Integration

- `fx mcp` — Model Context Protocol server for AI assistants
- IDE tool definitions for AI-powered development
- `fx configure-ai-agents` — generate AI agent configuration files

### Additional CLI Commands

- `fx show <project>` — project details
- `fx format` / `fx format:check` — formatting across all packages
- `fx analyze` — static analysis across all packages
- `fx bootstrap` — run `dart pub get` at workspace root
- `fx release` — manage package versions and changelogs
- `fx import <package>` — import external packages into workspace
- `fx repair` — scan and fix workspace issues
- `fx sync` / `fx sync:check` — workspace consistency
- `fx report` — environment and workspace info for bug reports
- `fx reset` — clear all caches and generated artifacts
- `fx ci-info` — CI provider detection and metadata as JSON
- TUI output formatter with progress indicators

### Documentation

- Documentation site built with Jaspr (static Dart web framework)
- Getting started guides, concept docs, feature docs, recipes, and reference
- Example monorepo with `shared` and `app` packages
