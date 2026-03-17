# Nx Monorepo Features - Exhaustive Reference (Excluding Nx Cloud)

> Research compiled from official Nx documentation (nx.dev), GitHub repository, and release blog posts.
> Current as of Nx v22.4 (January 2026).

---

## Table of Contents

1. [CLI Commands & Flags](#1-cli-commands--flags)
2. [nx.json Configuration](#2-nxjson-configuration)
3. [Project Configuration](#3-project-configuration-projectjsonpackagejson)
4. [Task Execution](#4-task-execution)
5. [Caching](#5-caching)
6. [Project Graph](#6-project-graph)
7. [Module Boundary Enforcement](#7-module-boundary-enforcement)
8. [Conformance Rules](#8-conformance-rules)
9. [Release System](#9-release-system-nx-release)
10. [Migration System](#10-migration-system)
11. [Plugin System](#11-plugin-system)
12. [Code Generation](#12-code-generation)
13. [Nx Console IDE Extension](#13-nx-console-ide-extension)
14. [Nx Daemon](#14-nx-daemon)
15. [MCP Server](#15-mcp-server)
16. [Format/Lint Integration](#16-formatlint-integration)
17. [Watch Mode](#17-watch-mode)
18. [Batch & Local Distribution](#18-batch--local-distribution)
19. [Environment Variable & Runtime Inputs](#19-environment-variable--runtime-inputs)
20. [External Dependency Hashing](#20-external-dependency-hashing)
21. [Sync Generators](#21-sync-generators)
22. [Terminal UI (TUI)](#22-terminal-ui-tui)
23. [Powerpack Features](#23-powerpack-features)
24. [AI Agent Integration](#24-ai-agent-integration)
25. [Official Plugins](#25-official-plugins)

---

## 1. CLI Commands & Flags

### `nx run <target> [project]`

Run a single target for a project.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--batch` | boolean | `false` | Run task(s) in batches for executors which support batches |
| `--configuration`, `-c` | string | — | Configuration to use when performing tasks |
| `--exclude` | string | — | Exclude certain projects from being processed |
| `--excludeTaskDependencies` | boolean | `false` | Skip running dependent tasks first |
| `--graph` | string | — | Show task graph (file path, "stdout", or browser) |
| `--nxBail` | boolean | `false` | Stop after first failed task |
| `--nxIgnoreCycles` | boolean | `false` | Ignore cycles in the task graph |
| `--outputStyle` | string | — | Log format: `tui`, `dynamic`, `dynamic-legacy`, `static`, `stream`, `stream-without-prefixes` |
| `--parallel` | string | `3` | Max number of parallel processes |
| `--project` | string | — | Target project |
| `--runner` | string | — | Tasks runner configured in nx.json |
| `--skipNxCache` / `--disableNxCache` | boolean | `false` | Rerun tasks ignoring cache |
| `--skipRemoteCache` / `--disableRemoteCache` | boolean | `false` | Disable remote cache |
| `--skipSync` | boolean | `false` | Skip sync generators |
| `--tui` | boolean | — | Enable/disable Terminal UI |
| `--tuiAutoExit` | string | — | Auto-exit TUI after completion (true/false/seconds) |
| `--verbose` | boolean | `false` | Print additional info (stack traces) |
| `--version` | boolean | — | Show version number |

### `nx run-many`

Run targets across multiple projects.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--all` | boolean | — | **Deprecated** - run-many runs all projects by default |
| `--batch` | boolean | `false` | Execute tasks in batches |
| `--configuration`, `-c` | string | — | Configuration to use |
| `--exclude` | string | — | Exclude specific projects |
| `--excludeTaskDependencies` | boolean | `false` | Skip dependent tasks |
| `--graph` | string | — | Show task graph |
| `--nxBail` | boolean | `false` | Stop after first failure |
| `--nxIgnoreCycles` | boolean | `false` | Ignore task graph cycles |
| `--outputStyle` | string | — | Log format (same choices as `run`) |
| `--parallel` | string | `3` | Max parallel processes |
| `--projects`, `-p` | string | — | Comma/space-delimited project names/patterns |
| `--runner` | string | — | Tasks runner name |
| `--skipNxCache` / `--disableNxCache` | boolean | `false` | Ignore cache |
| `--skipRemoteCache` / `--disableRemoteCache` | boolean | `false` | Disable remote cache |
| `--skipSync` | boolean | `false` | Skip sync generators |
| `--targets`, `--target`, `-t` | string | — | Tasks to run |
| `--tui` | boolean | — | Enable/disable TUI |
| `--tuiAutoExit` | string | — | Auto-exit behavior |
| `--verbose` | boolean | `false` | Print additional info |

### `nx affected`

Run targets on projects affected by changes.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--all` | boolean | — | **Deprecated** - use `run-many` instead |
| `--base` | string | — | Base of current branch (usually main) |
| `--batch` | boolean | `false` | Execute tasks in batches |
| `--configuration`, `-c` | string | — | Configuration to use |
| `--exclude` | string | — | Exclude projects |
| `--excludeTaskDependencies` | boolean | `false` | Skip dependent tasks |
| `--files` | string | — | Directly specify changed files (comma/space delimited) |
| `--graph` | string | — | Show task graph |
| `--head` | string | — | Latest commit (usually HEAD) |
| `--nxBail` | boolean | `false` | Stop after first failure |
| `--nxIgnoreCycles` | boolean | `false` | Ignore cycles |
| `--outputStyle` | string | — | Log format |
| `--parallel` | string | `3` | Max parallel processes |
| `--runner` | string | — | Tasks runner |
| `--skipNxCache` / `--disableNxCache` | boolean | `false` | Ignore cache |
| `--skipRemoteCache` / `--disableRemoteCache` | boolean | `false` | Disable remote cache |
| `--skipSync` | boolean | `false` | Skip sync generators |
| `--targets`, `--target`, `-t` | string | — | Tasks to run |
| `--tui` | boolean | — | Enable/disable TUI |
| `--tuiAutoExit` | string | — | Auto-exit behavior |
| `--uncommitted` | boolean | — | Include uncommitted changes |
| `--untracked` | boolean | — | Include untracked changes |
| `--verbose` | boolean | `false` | Print additional info |

### `nx graph`

Visualize the project or task graph.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--affected` | boolean | — | Highlight affected projects |
| `--base` | string | — | Base branch |
| `--exclude` | string | — | Exclude projects |
| `--file` | string | — | Output file (e.g. `output.json` or `dep-graph.html`) |
| `--files` | string | — | Specify changed files directly |
| `--focus` | string | — | Show graph for a particular project and its ancestors/descendants |
| `--groupByFolder` | boolean | — | Group projects by folder |
| `--head` | string | — | Latest commit |
| `--host` | string | — | Bind server to specific IP |
| `--open` | boolean | `true` | Open in browser |
| `--port` | number | — | Bind to specific port |
| `--print` | boolean | — | Print to stdout |
| `--targets` | string | — | Target to show tasks for in task graph |
| `--uncommitted` | boolean | — | Show uncommitted changes |
| `--untracked` | boolean | — | Show untracked changes |
| `--verbose` | boolean | — | Print additional info |
| `--view` | string | `projects` | Choose view: `projects` or `tasks` |
| `--watch` | boolean | `true` | Watch for changes and update in browser |

### `nx generate <plugin>:<generator> [options]` (alias: `nx g`)

Run a code generator.

| Flag | Type | Description |
|------|------|-------------|
| `--defaults` | boolean | Use default values for unspecified options |
| `--dryRun` | boolean | Preview changes without applying |
| `--interactive` | boolean | Enable interactive prompts |
| `--quiet` | boolean | Suppress output |
| `--verbose` | boolean | Print additional info |
| (generator-specific flags) | varies | Each generator defines its own schema |

### `nx migrate [packageAndVersion]`

Update Nx and installed plugins, run migration scripts.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--commitPrefix` | string | `"chore: [nx migration] "` | Commit prefix for each migration |
| `--createCommits`, `-C` | boolean | `false` | Auto-create git commit after each migration |
| `--excludeAppliedMigrations` | boolean | `false` | Exclude previously applied migrations (use with `--from`) |
| `--from` | string | — | Override installed versions (e.g. `@nx/react@16.0.0,@nx/js@16.0.0`) |
| `--ifExists` | boolean | `false` | Run migrations only if migrations file exists |
| `--interactive` | boolean | `false` | Prompt for optional package updates |
| `--packageAndVersion` | string | — | Target package and version |
| `--runMigrations` | string | — | Execute migrations from file (default: `migrations.json`) |
| `--to` | string | — | Override target versions |
| `--verbose` | boolean | — | Print additional info |

### `nx release`

Create a version, generate changelog, and publish packages.

| Flag | Type | Description |
|------|------|-------------|
| `--dry-run` | boolean | Preview without publishing |
| `--first-release` | boolean | First release (no prior tags/changelogs) |
| `--skip-publish` | boolean | Skip publishing step |
| `--verbose` | boolean | Print additional info including git commands |
| `--projects` | string | Filter projects (same specifiers as run-many) |

#### `nx release version`

Bump project versions.

| Flag | Type | Description |
|------|------|-------------|
| `--dry-run` | boolean | Preview changes |
| `--first-release` | boolean | First release |
| `--preid` | string | Prerelease identifier (e.g. `alpha`, `beta`) |
| `--specifier` | string | Version bump type or exact version |
| `--verbose` | boolean | Additional info |

#### `nx release changelog [version]`

Generate changelogs from commits or version plans.

| Flag | Type | Description |
|------|------|-------------|
| `--dry-run` | boolean | Preview changes |
| `--first-release` | boolean | First release |
| `--from` | string | Start ref for changelog |
| `--to` | string | End ref for changelog |
| `--verbose` | boolean | Additional info |

#### `nx release publish`

Publish packages to registries.

| Flag | Type | Description |
|------|------|-------------|
| `--dry-run` | boolean | Preview without publishing |
| `--registry` | string | Override registry URL |
| `--tag` | string | Dist-tag for publish |
| `--verbose` | boolean | Additional info |

#### `nx release plan`

Create a version plan file (file-based versioning).

Interactive prompts guide through creation. Generates unique filenames in `.nx/version-plans/`.

#### `nx release plan:check`

Validate version plan files exist for changes.

| Flag | Type | Description |
|------|------|-------------|
| `--base` | string | Base ref |
| `--head` | string | Head ref |
| `--files` | string | Changed files |
| `--uncommitted` | boolean | Include uncommitted |
| `--verbose` | boolean | Show filtering details |

### `nx show`

Show workspace information.

#### `nx show project [projectName]`

| Flag | Type | Description |
|------|------|-------------|
| `--json` | boolean | Output as JSON |
| `--open` | boolean | Open in browser with `--web` |
| `--projectName`, `-p` | string | Project to display |
| `--verbose` | boolean | Additional info |
| `--web` | boolean | Show in browser (default in interactive mode) |

#### `nx show projects`

| Flag | Type | Description |
|------|------|-------------|
| `--affected` | boolean | Show only affected projects |
| `--base` | string | Base branch |
| `--exclude` | string | Exclude projects |
| `--files` | string | Changed files for affected calculation |
| `--head` | string | Head ref |
| `--json` | boolean | Output as JSON |
| `--projects`, `-p` | string | Filter by pattern |
| `--sep` | string | Custom separator |
| `--type` | string | Filter by type: `app`, `lib`, `e2e` |
| `--uncommitted` | boolean | Include uncommitted |
| `--untracked` | boolean | Include untracked |
| `--verbose` | boolean | Additional info |
| `--withTarget`, `-t` | string | Filter projects with a specific target |

### `nx watch`

Watch projects and execute commands on changes.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--all` | boolean | — | Watch all projects |
| `--includeDependentProjects`, `-d` | boolean | — | Include dependent projects |
| `--initialRun`, `-i` | boolean | `false` | Run command once before watching |
| `--projects`, `-p` | string | — | Projects to watch (comma/space delimited) |
| `--verbose` | boolean | — | Detailed output |

**Environment variables available in command:**
- `$NX_PROJECT_NAME` - Name of changed project
- `$NX_FILE_CHANGES` - Changed files

### `nx exec`

Execute a command within the context of a specific project (inherits Nx environment).

### `nx reset`

Clear cached artifacts, metadata, and shut down daemon.

| Flag | Type | Description |
|------|------|-------------|
| `--onlyCache` | boolean | Clear only local cache entries |
| `--onlyCloud` | boolean | Reset Nx Cloud client only |
| `--onlyDaemon` | boolean | Stop daemon and clear workspace data |
| `--onlyWorkspaceData` | boolean | Clear workspace data directory (partial results, incremental data) |

### `nx repair`

Repair unsupported configuration by running migrations against the repo.

| Flag | Type | Description |
|------|------|-------------|
| `--verbose` | boolean | Print additional info |

### `nx report`

Report useful version numbers for bug reports.

(No special flags beyond `--help`)

### `nx sync`

Execute all sync generators to synchronize files with configuration.

| Flag | Type | Description |
|------|------|-------------|
| `--verbose` | boolean | Print additional info |

### `nx sync:check`

Check if sync generators would produce changes (fails if changes needed).

| Flag | Type | Description |
|------|------|-------------|
| `--verbose` | boolean | Print additional info |

### `nx daemon`

Control the Nx Daemon process.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--start` | boolean | `false` | Start the daemon |
| `--stop` | boolean | `false` | Stop the daemon |
| `--verbose` | boolean | — | Print additional info |

### `nx mcp`

Start the Nx MCP (Model Context Protocol) server for AI agent integration.

(Minimal flags documented; see MCP section below.)

### `nx init`

Initialize Nx in an existing workspace.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--aiAgents` | string | — | AI agents to set up: `claude`, `codex`, `copilot`, `cursor`, `gemini`, `opencode` |
| `--force` | boolean | `false` | Force migration (CRA projects) |
| `--interactive` | boolean | `true` | Enable interactive prompts |
| `--nxCloud` | boolean | — | Set up distributed caching |
| `--useDotNxInstallation` | boolean | `false` | Install in `.nx` directory |

### `nx add <package>`

Install and initialize a plugin.

| Flag | Type | Description |
|------|------|-------------|
| `--packageSpecifier` | string | Package name and optional version |
| `--updatePackageScripts` | boolean | Update package.json scripts with inferred targets (default true for core plugins) |
| `--verbose` | boolean | Print additional info |

### `nx import [sourceRepository] [destinationDirectory]`

Import a project from another repository (preserving git history).

| Flag | Type | Description |
|------|------|-------------|
| `--depth` | number | Clone depth for source repo |
| `--destinationDirectory` / `--destination` | string | Target directory in workspace |
| `--interactive` | boolean | Interactive mode (default: true) |
| `--ref` | string | Branch from source repository |
| `--sourceDirectory` / `--source` | string | Directory in source repo |
| `--sourceRepository` | string | Remote URL or local path |
| `--verbose` | boolean | Print additional info |

### `nx format:check` / `nx format:write`

Check or apply formatting (uses Prettier).

| Flag | Type | Description |
|------|------|-------------|
| `--all` | boolean | Format all projects |
| `--base` | string | Base branch |
| `--exclude` | string | Exclude projects |
| `--files` | string | Specific changed files |
| `--head` | string | Head ref |
| `--libs-and-apps` | boolean | Format only libraries and applications |
| `--projects` | string | Projects to format |
| `--sort-root-tsconfig-paths` | boolean | Sort tsconfig paths (default: false, override with `NX_FORMAT_SORT_TSCONFIG_PATHS`) |
| `--uncommitted` | boolean | Uncommitted changes |
| `--untracked` | boolean | Untracked changes |

### `nx list [plugin]`

List installed and available plugins, or show generators/executors of a specific plugin.

### `nx configure-ai-agents`

Configure AI agent integrations.

| Flag | Type | Description |
|------|------|-------------|
| `--agents` | string | AI agents to set up: `claude`, `codex`, `copilot`, `cursor`, `gemini`, `opencode` |
| `--check` | string | Check configurations: `outdated` (configured only) or `all` |
| `--interactive` | boolean | Enable interactive prompts (default: true) |
| `--verbose` | boolean | Print additional info |

### `nx conformance` / `nx conformance:check`

Run conformance rules. `conformance` evaluates and applies fixes; `conformance:check` evaluates only (CI-appropriate).

### `nx apply-locally`

Apply changes from a remote source locally.

---

## 2. nx.json Configuration

### Root-Level Properties

```jsonc
{
  // Extend a base configuration
  "extends": "string",

  // Default base branch for affected calculations
  "defaultBase": "main",

  // Max parallel tasks
  "parallel": 3,

  // Whether cache captures stderr alongside stdout
  "captureStderr": true,

  // Disable Nx caching globally
  "skipNxCache": false,

  // Local cache storage path
  "cacheDirectory": ".nx/cache",

  // Max local cache size (bytes, KB, MB, GB, or 0 for unlimited)
  // Override with NX_MAX_CACHE_SIZE env var
  "maxCacheSize": "10GB",

  // Hash only active project paths in tsconfig
  "selectivelyHashTsConfig": false,

  // Reusable input definitions
  "namedInputs": {
    "default": ["{projectRoot}/**/*"],
    "production": [
      "default",
      "!{projectRoot}/**/*.spec.ts",
      "!{projectRoot}/jest.config.ts"
    ],
    "sharedGlobals": [
      { "runtime": "node --version" }
    ]
  },

  // Default target configuration
  "targetDefaults": {
    "build": {
      "inputs": ["production", "^production"],
      "outputs": ["{projectRoot}/dist"],
      "cache": true,
      "dependsOn": ["^build"],
      "executor": "@nx/vite:build",
      "options": {},
      "configurations": {
        "production": {}
      }
    }
  },

  // Plugin configuration
  "plugins": [
    "@nx/vite/plugin",
    {
      "plugin": "@nx/eslint/plugin",
      "options": {
        "targetName": "lint"
      },
      "include": ["packages/**/*"],
      "exclude": ["legacy/**/*"]
    }
  ],

  // Default generator options
  "generators": {
    "@nx/react:component": {
      "style": "css"
    }
  },

  // Release configuration (see Release section)
  "release": { /* ... */ },

  // Sync configuration
  "sync": {
    "applyChanges": true,
    "globalGenerators": ["@nx/js:typescript-sync"],
    "generatorOptions": {
      "@nx/js:typescript-sync": {}
    },
    "disabledTaskSyncGenerators": []
  },

  // Terminal UI configuration
  "tui": {
    "enabled": true,
    "autoExit": true  // boolean or number (seconds)
  },

  // Conformance rules
  "conformance": {
    "outputPath": "conformance-results.json",  // or false to disable
    "rules": [
      {
        "rule": "@nx/conformance/enforce-project-boundaries",
        "options": {},
        "projects": ["*"],
        "explanation": "Why this rule exists",
        "status": "enforced"  // "enforced" | "evaluated" | "disabled"
      }
    ]
  },

  // Nx Cloud (excluded from this doc)
  "nxCloudId": "...",
  "nxCloudUrl": "...",
  "encryptionKey": "..."
}
```

### Plugin Configuration Object

```jsonc
{
  "plugin": "string",           // Package name or path
  "options": {},                // Plugin-specific options
  "include": ["glob/**"],      // Config file patterns to include
  "exclude": ["glob/**"]       // Config file patterns to exclude
}
```

### Target Defaults Structure

```jsonc
{
  "targetDefaults": {
    "<targetName>": {
      "inputs": ["production", "^production"],
      "outputs": ["{projectRoot}/dist"],
      "cache": true,
      "dependsOn": ["^build", "prebuild"],
      "executor": "@nx/webpack:webpack",
      "options": {},
      "configurations": {
        "production": {},
        "development": {}
      },
      "defaultConfiguration": "production",
      "continuous": false,
      "parallelism": true,
      "syncGenerators": ["@nx/js:typescript-sync"],
      "metadata": {}
    }
  }
}
```

### Release Configuration (Full)

```jsonc
{
  "release": {
    // Projects to include
    "projects": ["packages/*"],

    // Release coordination mode
    "projectsRelationship": "fixed",  // "fixed" | "independent"

    // Enable version plans
    "versionPlans": true,  // or { "ignorePatternsForPlanCheck": ["**/*.spec.ts"] }

    // Git tag configuration
    "releaseTag": {
      "pattern": "v{version}",  // fixed default
      // "pattern": "{projectName}@{version}",  // independent default
      // Interpolation vars: {version}, {projectName}, {releaseGroupName}
      "requireSemver": false,
      "strictPreid": true,
      "preferDockerVersion": false,
      "checkAllBranchesWhen": false  // boolean | string[]
    },

    // Versioning phase
    "version": {
      "conventionalCommits": true,
      "manifestRootsToUpdate": ["./"],
      "versionActionsOptions": {},
      "preserveMatchingDependencyRanges": true,
      "updateDependents": "auto"  // "always" | "auto" | "never"
    },

    // Changelog generation
    "changelog": {
      "workspaceChangelog": {
        "file": true,
        "createRelease": "github",  // "github" | false
        "replaceExistingContents": false
      },
      "projectChangelogs": {
        "file": true,
        "createRelease": false,
        "replaceExistingContents": false
      },
      "git": {
        "commit": true,
        "tag": true
      }
    },

    // Git operations
    "git": {
      "commit": true,
      "tag": true,
      "commitMessage": "chore(release): publish {version}"
    },

    // Docker versioning (experimental)
    "docker": {
      "preVersionCommand": "string",
      "versionSchemes": {
        "production": "{projectName}-{currentDate|YYYYMMDD}-{shortCommitSha}"
        // Placeholders: {projectName}, {currentDate}, {currentDate|FORMAT},
        //   {shortCommitSha}, {commitSha}, {versionActionsVersion}
      },
      "skipVersionActions": ["project-name"],
      "repositoryName": "string",
      "registryUrl": "string"
    },

    // Release groups
    "groups": {
      "group-name": {
        "projects": ["pkg-a", "pkg-b"],
        "projectsRelationship": "fixed",  // "fixed" | "independent"
        "docker": { /* DockerConfig */ },
        "changelog": { /* ChangelogConfig */ },
        "groupPreVersionCommand": "string"
      }
    }
  }
}
```

---

## 3. Project Configuration (project.json/package.json)

### Root-Level Properties

```jsonc
{
  // Project identifier
  "name": "my-project",

  // Project root folder
  "root": "packages/my-project",

  // Source code directory
  "sourceRoot": "packages/my-project/src",

  // Type classification
  "projectType": "application",  // "application" | "library"

  // Tags for module boundary enforcement
  "tags": ["scope:shared", "type:util"],

  // Manual dependency declarations
  "implicitDependencies": ["other-project"],
  // Use "!other-project" to remove an inferred dependency

  // Reusable input definitions (project-scoped)
  "namedInputs": {
    "production": ["default", "!{projectRoot}/**/*.spec.ts"]
  },

  // Metadata
  "metadata": {
    "description": "Shared utilities library",
    "technologies": ["react", "typescript"]  // often inferred by plugins
  },

  // Release overrides
  "release": {
    "docker": {
      "repositoryName": "my-docker-repo"
    }
  },

  // Task definitions
  "targets": { /* see below */ }
}
```

### Target Definition

```jsonc
{
  "targets": {
    "build": {
      // Executor (plugin:executor format)
      "executor": "@nx/vite:build",

      // OR simple command shorthand
      "command": "tsc -p tsconfig.lib.json",

      // Executor-specific options
      "options": {
        "outputPath": "dist/packages/my-lib"
      },

      // Named configuration variants
      "configurations": {
        "production": {
          "optimization": true
        },
        "development": {
          "optimization": false
        }
      },

      // Default configuration when none specified
      "defaultConfiguration": "production",

      // Cache inputs for hash calculation
      "inputs": [
        "production",
        "^production",
        { "externalDependencies": ["vite"] },
        { "runtime": "node --version" },
        { "env": "MY_ENV_VAR" }
      ],

      // Outputs to cache
      "outputs": [
        "{projectRoot}/dist",
        "{workspaceRoot}/dist/{projectRoot}",
        "{projectRoot}/build/**/*.{js,map}"  // GlobSet syntax
      ],

      // Task dependencies
      "dependsOn": [
        "^build",         // dependency projects' build
        "prebuild",       // same project's prebuild
        "build-*",        // wildcard - current project targets (v19.5+)
        "^build-*",       // wildcard - dependency targets
        {
          "target": "build",
          "projects": "dependencies",  // or "self" or specific project names
          "params": "forward"          // "forward" | "ignore"
        }
      ],

      // Enable caching (Nx 17+)
      "cache": true,

      // Mark as long-running / continuous (Nx 21+)
      "continuous": true,

      // Enable/disable parallel execution (Nx 19.5+)
      "parallelism": true,

      // Sync generators to run before task (Nx 19.8+)
      "syncGenerators": ["@nx/js:typescript-sync"],

      // Target metadata
      "metadata": {
        "description": "Build the project",
        "technologies": ["vite"]
      }
    }
  }
}
```

### package.json Nx Configuration

```jsonc
{
  "name": "my-package",
  "scripts": {
    "build": "tsc",
    "test": "jest"
  },
  "nx": {
    "targets": {
      "build": {
        "inputs": ["production", "^production"],
        "outputs": ["{projectRoot}/dist"],
        "cache": true,
        "dependsOn": ["^build"]
      }
    },
    "namedInputs": {
      "production": ["default", "!{projectRoot}/**/*.spec.ts"]
    },
    "implicitDependencies": ["other-project"],
    "includedScripts": ["build", "test"],  // limit which scripts Nx recognizes
    "tags": ["scope:shared"]
  }
}
```

---

## 4. Task Execution

### Task Orchestration Features

- **Parallel execution**: Tasks run concurrently (default max 3, configurable via `--parallel`)
- **Dependency-aware ordering**: Tasks respect `dependsOn` configuration, running prerequisites first
- **Pipeline configuration**: Global via `targetDefaults` in nx.json, per-project in project.json
- **`^` prefix**: Run target on all dependency projects first (e.g., `^build`)
- **Wildcard patterns** (v19.5+): `build-*`, `^build-*`, `*build-*`
- **Cross-project dependencies**: `{ "target": "build", "projects": "dependencies" }`
- **Parameter forwarding**: `{ "params": "forward" }` passes CLI args to dependent tasks
- **Multi-target execution**: `nx run-many -t build lint test`
- **Project filtering**: `nx run-many -t build -p header,footer` or glob patterns
- **Exclude projects**: `--exclude=project-name`
- **Skip task dependencies**: `--excludeTaskDependencies`

### Continuous Tasks (Nx 21+)

- Mark tasks with `"continuous": true` in target config
- Dependent tasks start without waiting for continuous tasks to finish
- Use case: `dev` server that serves frontend while running API server
- Enables watch-mode code generators and buildable library watchers
- Works with TUI for multi-panel output

### Parallelism Control (Nx 19.5+)

- `"parallelism": false` prevents task from running in parallel with other tasks on same machine
- Use case: tasks requiring shared resources (ports, memory)
- In distributed execution, tasks still run simultaneously on different machines

### Batch Execution

- `--batch` flag sends tasks to executors in batches
- Primarily used with Gradle plugin (sends tasks to Gradle in batches instead of one-by-one)
- Executors must support batch processing

### Root-Level Tasks

- Define in root `package.json` or root `project.json`
- Can be cached like any other task
- Useful for workspace-wide operations

### Task Graph Visualization

- `--graph` flag on any run command shows the task graph
- Outputs to browser, file, or stdout
- Shows dependency ordering

---

## 5. Caching

### How Caching Works

1. Nx computes a **computation hash** before running each task
2. Checks local cache first, then remote cache (if configured)
3. If found: restores terminal output + file artifacts
4. If not found: runs task, stores results

### Hash Components

- Source files of project and its dependencies
- Relevant global configuration
- Versions of external dependencies
- Runtime values (e.g., Node version)
- CLI command flags
- Environment variables (when configured)

### Cache Configuration

```jsonc
// Enable caching per target
"cache": true

// Define what to cache
"outputs": [
  "{projectRoot}/dist",
  "{workspaceRoot}/coverage/{projectRoot}"
]

// Define what affects the hash
"inputs": [
  "production",         // named input reference
  "^production",        // dependency inputs (^ prefix)
  "default",            // built-in: all project files
  "{projectRoot}/src/**/*.ts",  // file glob
  "!{projectRoot}/**/*.spec.ts", // exclusion
  { "runtime": "node --version" },  // runtime command
  { "env": "MY_API_KEY" },          // environment variable
  { "externalDependencies": ["vite", "webpack"] }  // specific npm packages
]
```

### Named Inputs

Defined in `nx.json` `namedInputs` or project-level `namedInputs`:

```jsonc
{
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).ts",
      "!{projectRoot}/jest.config.ts",
      "!{projectRoot}/tsconfig.spec.json"
    ],
    "sharedGlobals": [
      { "runtime": "node --version" }
    ]
  }
}
```

### Input Types

| Type | Syntax | Description |
|------|--------|-------------|
| File set | `"{projectRoot}/src/**/*"` | Glob pattern for files |
| Exclusion | `"!{projectRoot}/**/*.spec.ts"` | Exclude files from hash |
| Named input ref | `"production"` | Reference to namedInputs |
| Dependency inputs | `"^production"` | Include dependency project inputs |
| Runtime | `{ "runtime": "node --version" }` | Execute command, hash output |
| Environment var | `{ "env": "MY_ENV_VAR" }` | Hash env var value |
| External deps | `{ "externalDependencies": ["vite"] }` | Hash specific npm package versions |

### Path Placeholders

- `{projectRoot}` - Project's root directory
- `{workspaceRoot}` - Workspace root directory

### Output Glob Syntax (GlobSet)

- Basic: `"{projectRoot}/dist"`
- Glob: `"**/*.{js,map}"`
- Exclusion: `"dist/!(cache|.next)/**/*.js"`

### Cache Configuration

- `cacheDirectory`: Local cache path (default: `.nx/cache`)
- `maxCacheSize`: Size limit (e.g., `"10GB"`, `0` for unlimited)
- `NX_MAX_CACHE_SIZE` env var override
- `skipNxCache`: Disable caching globally
- `captureStderr`: Include stderr in cached output

### Input Precedence (highest to lowest)

1. Project-level configuration (project.json / package.json)
2. Workspace-level targetDefaults (nx.json)
3. Plugin-inferred inputs

Each level **completely overwrites** lower levels (no merging).

### Self-Hosted Remote Cache (Free since v20.8)

Custom cache server via environment variables:
- `NX_SELF_HOSTED_REMOTE_CACHE_SERVER` - Server endpoint URL
- `NX_SELF_HOSTED_REMOTE_CACHE_ACCESS_TOKEN` - Auth token
- `NODE_TLS_REJECT_UNAUTHORIZED` - TLS validation toggle

**OpenAPI spec** for custom servers:
- `PUT /v1/cache/{hash}` - Upload task outputs (binary tar)
- `GET /v1/cache/{hash}` - Download cached outputs
- Bearer token authentication, standard HTTP status codes

**Official cache adapters** (Powerpack, require license for bucket-based):
- `@nx/s3-cache` - Amazon S3
- `@nx/gcs-cache` - Google Cloud Storage
- `@nx/azure-cache` - Azure Blob Storage
- `@nx/shared-fs-cache` - Shared filesystem

---

## 6. Project Graph

### Features

- **Automatic detection**: Nx analyzes source code imports, package.json dependencies, and plugin-provided dependencies
- **Visualization**: `nx graph` opens interactive browser-based graph
- **Task graph view**: `nx graph --view=tasks --targets=build` shows task execution order
- **Focus mode**: `--focus=project-name` shows ancestors and descendants
- **Group by folder**: `--groupByFolder` groups projects visually
- **Affected highlighting**: `--affected` highlights impacted projects
- **Export**: `--file=output.json` or `--file=dep-graph.html`
- **Print to stdout**: `--print` for JSON output in terminal
- **Watch mode**: Auto-updates when files change (default enabled)
- **Custom host/port**: `--host` and `--port` for server binding
- **Project filtering**: `--exclude` to remove projects from display

### Affected Algorithm

- Compares `--base` (default: `defaultBase` from nx.json) with `--head` (default: HEAD)
- Determines which projects are affected by file changes
- Can use `--files` to specify changed files directly
- `--uncommitted` and `--untracked` for local change detection

---

## 7. Module Boundary Enforcement

### ESLint Rule: `@nx/enforce-module-boundaries`

**Package**: `@nx/eslint-plugin`

#### Rule Options

| Option | Type | Description |
|--------|------|-------------|
| `depConstraints` | array | Dependency constraints between projects |
| `allow` | array | Import patterns to whitelist (skip checks) |
| `allowCircularSelfDependency` | boolean | Allow project to import from its own alias |
| `enforceBuildableLibDependency` | boolean | Prevent importing non-buildable into buildable |
| `banTransitiveDependencies` | boolean | Error on transitive dependency imports (recommended) |
| `checkNestedExternalImports` | boolean | Check nested external import paths |

#### depConstraints Object

```jsonc
{
  "depConstraints": [
    {
      // Match source projects by tag
      "sourceTag": "scope:feature",
      // OR match multiple tags
      "allSourceTags": ["scope:feature", "type:ui"],

      // Allowed dependency tags
      "onlyDependOnLibsWithTags": ["scope:shared", "scope:feature"],

      // Banned npm package imports (supports globs)
      "bannedExternalImports": ["@nestjs/*", "express"],

      // Allowed npm package imports (restrictive approach)
      "allowedExternalImports": ["react", "react-dom"]
    }
  ]
}
```

#### Tag Matching Formats

- Exact string: `"scope:shared"`
- Wildcard/glob: `"scope:*"`
- Regex: `"/^scope.*/"`
- Star (allow all): `"*"`

#### Multi-Dimensional Tags

Tags can encode multiple dimensions (e.g., `scope:feature`, `type:ui`, `platform:web`), with constraints checking across dimensions.

### Conformance-Based Enforcement (Language-Agnostic)

Uses `@nx/conformance/enforce-project-boundaries` rule (see Conformance section). Works for any language, not just JS/TS.

---

## 8. Conformance Rules

### Configuration in nx.json

```jsonc
{
  "conformance": {
    "outputPath": "conformance-results.json",  // or false
    "rules": [
      {
        "rule": "@nx/conformance/enforce-project-boundaries",
        "options": {
          "depConstraints": [...],
          "requireBuildableDependenciesForBuildableProjects": false,
          "buildTargetNames": ["build"],
          "ignoredCircularDependencies": [["project-a", "project-b"]]
        },
        "projects": ["*"],  // or specific patterns
        "explanation": "Reason for this rule",
        "status": "enforced"  // "enforced" | "evaluated" | "disabled"
      }
    ]
  }
}
```

### Built-In Rules

| Rule | ID | Description |
|------|----|-------------|
| Enforce Project Boundaries | `@nx/conformance/enforce-project-boundaries` | Dependency constraints across all project types (language-agnostic) |
| Ensure Owners | `@nx/conformance/ensure-owners` | Require every project to have an owner |

#### Enforce Project Boundaries Options

- `depConstraints`: Array of source/target dependency rules
  - `sourceTag` / `allSourceTags`: Source matching
  - `onlyDependOnProjectsWithTags`: Allowed targets
  - `notDependOnProjectsWithTags`: Prohibited targets
- `requireBuildableDependenciesForBuildableProjects`: boolean or object
- `buildTargetNames`: string[] (default: `["build"]`)
- `ignoredCircularDependencies`: Array of `[string, string]` pairs

### Rule Status Values

- `"enforced"` - Violations cause failure
- `"evaluated"` - Violations reported but don't cause failure
- `"disabled"` - Rule not evaluated

### Project Matcher

```jsonc
{
  "projects": [
    "project-name",
    {
      "matcher": "packages/*",
      "explanation": "Why these projects"
    }
  ]
}
```

### Custom Rules

- Can be local paths, module paths, or `nx-cloud://` rule IDs
- Custom rule API available for creating organization-specific rules

### Commands

- `nx conformance` - Evaluate and auto-fix
- `nx conformance:check` - Evaluate only (for CI)

---

## 9. Release System (nx release)

### Three Phases

1. **Version** - Determine next version, update project files and dependents
2. **Changelog** - Generate changelogs from commits or version plans
3. **Publish** - Publish packages to registries

### Versioning Features

- **Semantic versioning** (major/minor/patch)
- **Conventional commits** - Automate version bumps from commit messages
- **Version plans** - File-based versioning alternative (`.nx/version-plans/*.md`)
- **Prerelease support** - `--preid=alpha|beta|rc`
- **Custom version schemes** - `requireSemver: false`
- **Fixed versioning** - All projects share same version
- **Independent versioning** - Each project versioned separately
- **Release groups** - Organize projects into groups with group-specific settings
- **updateDependents** - `"always"` | `"auto"` | `"never"` for dependent project updates
- **preserveMatchingDependencyRanges** - Keep ranges if satisfied by new version
- **manifestRootsToUpdate** - Paths to manifest files for version updates
- **Custom version actions** - For non-JS packages (Java, Go, Rust) via `versionActionsOptions`

### Version Plans

- Files in `.nx/version-plans/` directory (git-tracked)
- YAML front matter maps projects to bump types
- Markdown body becomes changelog entry
- `nx release plan` - Interactive creation
- `nx release plan:check` - CI validation
- `ignorePatternsForPlanCheck` - Ignore patterns for plan:check (gitignore semantics)

### Changelog Features

- Workspace-level changelog
- Per-project changelogs
- GitHub release creation (`createRelease: "github"`)
- Replace or prepend mode
- Custom changelog format/commit types
- Git commit and tag integration

### Publishing

- Publish to npm, crates.io, Docker registries
- Registry override
- Dist-tag support
- Dry-run mode
- Pre-publishing build execution

### Git Integration

- Auto-commit with customizable message: `"chore(release): publish {version}"`
- Auto-tag with customizable pattern: `"v{version}"` or `"{projectName}@{version}"`
- Tag interpolation: `{version}`, `{projectName}`, `{releaseGroupName}`

### Docker Support (Experimental)

- Docker image versioning
- Custom version schemes with date/commit SHA placeholders
- Pre-version commands
- Skip version actions per project
- Repository name and registry URL configuration

### Programmatic API

- Node.js interface for custom release workflows
- Enables dynamic, programmatic control beyond CLI

---

## 10. Migration System

### How It Works

1. `nx migrate latest` (or specific version) - Updates package.json, generates `migrations.json`
2. `nx migrate --run-migrations` - Executes migration scripts
3. Review and commit changes

### Migration Features

- **Automatic dependency synchronization** - All @nx/ packages synced to same version
- **Per-migration commits** - `--createCommits` with `--commitPrefix`
- **Interactive mode** - `--interactive` for selective migration acceptance
- **Selective execution** - Edit `migrations.json` to skip specific migrations
- **Version range control** - `--from` and `--to` flags for specific version ranges
- **Conditional execution** - `--ifExists` runs only if migrations file present
- **Exclude applied** - `--excludeAppliedMigrations` skips already-applied migrations
- **Plugin migrations** - Each plugin can provide its own migration scripts
- **Source code updates** - Migrations can modify config files AND source code
- **`migrations.json` format** - Plugins define migrations in this file with version triggers

### Migration Generator Development

- Create migration generators with `@nx/plugin`
- Define in `migrations.json` with version triggers
- Simple dependency version changes can be config-only (no generator code needed)
- Access to full Nx Devkit for file manipulation

---

## 11. Plugin System

### NxPluginV2 Interface

```typescript
interface NxPluginV2<TOptions = unknown> {
  name: string;
  createNodes?: CreateNodesV2<TOptions>;
  createNodesV2?: CreateNodesV2<TOptions>;
  createDependencies?: CreateDependencies<TOptions>;
  createMetadata?: CreateMetadata<TOptions>;
  preTasksExecution?: PreTasksExecution<TOptions>;
  postTasksExecution?: PostTasksExecution<TOptions>;
}
```

### createNodesV2

```typescript
type CreateNodesV2<T> = readonly [
  projectFilePattern: string,  // glob pattern
  createNodesFunction: CreateNodesFunctionV2<T>
];
```

- Receives matched file paths and context object
- Returns projects and external nodes
- `AggregateCreateNodesError` for partial results with errors
- Used for **inferred tasks** - auto-detect tasks from config files

### createDependencies

```typescript
type CreateDependencies<T> = (
  options: T | undefined,
  context: CreateDependenciesContext
) => RawProjectGraphDependency[] | Promise<RawProjectGraphDependency[]>;
```

- Parse files to create dependencies in the project graph
- Returns array of dependency objects

### createMetadata

- Generate metadata for the project graph

### preTasksExecution / postTasksExecution

- Hooks that run before/after task execution
- Replaced the deprecated custom task runners API (removed in Nx 21)

### Plugin Options

- Configured in `nx.json` `plugins` array
- Plugin objects can have `options`, `include`, `exclude`
- Generic type parameter for typed options

### Plugin Development

- Use `@nx/plugin` package for scaffolding
- Generators: `nx g generator`, `nx g executor`, `nx g migration`
- `init` generator runs automatically when plugin installed via `nx add`
- Disable daemon during development: `NX_DAEMON=false`

### Inferred Tasks

- Plugins detect config files (e.g., `vite.config.ts`, `jest.config.ts`)
- Automatically create task definitions with correct cache settings
- Plugin processing order matters (last wins for same task name)
- Scoping via `include`/`exclude` glob patterns
- Override precedence: project config > targetDefaults > inferred

### API Evolution

- `createNodesV1` removed in Nx 21
- Standardizing on `createNodesV2` (v2 API)
- Nx 22: both exports work with v2 signature
- Nx 23: `createNodesV2` export deprecated in types

---

## 12. Code Generation

### Generators

- Invoked via `nx generate <plugin>:<generator> [options]` (or `nx g`)
- TypeScript functions accepting `Tree` and schema parameters
- Built on `@nx/devkit` helpers

### Key Devkit Helpers

- `addProjectConfiguration` - Add project to workspace
- `generateFiles` - Copy template files with variable substitution
- `formatFiles` - Format generated files
- `installPackagesTask` - Install dependencies
- `readProjectConfiguration` / `updateProjectConfiguration`
- `readNxJson` / `updateNxJson`
- `getProjects` - List all projects
- `joinPathFragments` - Path utilities
- `Tree` API - Virtual filesystem for atomic changes

### Generator Types

- **Plugin generators** - Shipped with Nx plugins
- **Workspace/local generators** - Custom generators in your repo
- **Preset generators** - Initialize new workspaces with specific configurations

### Schema System

- `schema.json` - JSON Schema defining generator options
- Supports interactive prompts (x-prompt)
- Default values, enums, required fields
- CLI flag generation from schema

### Discovery

- `nx list <plugin>` - Show available generators
- Nx Console IDE extension provides visual discovery
- Shorthand invocation by generator name (Nx prompts for plugin selection)

---

## 13. Nx Console IDE Extension

### Supported IDEs

- **VS Code** - Official (Nx team maintained)
- **JetBrains IDEs** - Official (Nx team maintained)
- **Neovim** - Community maintained (Equilibris/nx.nvim)

### Features

- **Task management** - Display and invoke inferred tasks from Project Details View
- **Code generation UI** - Visual interface for discovering and running generators
- **Project visualization** - Visualize project and task dependencies
- **AI integration** - Enhance AI tools with workspace-level context and up-to-date docs
- **Migration UI** (Nx 21+) - Step through migrations individually, view changes before approval, per-migration or batch commits

---

## 14. Nx Daemon

### Purpose

Background process that accelerates project graph computation by maintaining state between commands. Watches files and updates project graph incrementally.

### Technical Details

- Unix socket (macOS/Linux) or named pipe (Windows)
- One instance per workspace
- Auto-shuts down after 3 hours of inactivity
- Stops when Nx installation changes

### Default Behavior

| Environment | Default |
|-------------|---------|
| Local development | Enabled |
| CI environments | Disabled |
| Docker containers | Disabled (unless `NX_DAEMON=true`) |

### Configuration

- `useDaemonProcess: false` in nx.json runners options
- `NX_DAEMON=false` environment variable to disable
- `NX_DAEMON_SOCKET_DIR` - Custom socket directory (useful for Docker Compose)

### Management

- `nx daemon` - Show running daemon info, PID, log file path
- `nx daemon --start` / `--stop` - Control lifecycle
- `nx reset` - Shut down daemon and clear data
- `nx reset --onlyDaemon` - Stop daemon only

---

## 15. MCP Server

### `nx mcp`

Starts the Nx MCP (Model Context Protocol) server for AI agent integration.

- Provides workspace context to AI tools
- Exposes project graph, task information, and workspace metadata
- Used by Nx Console and AI coding assistants
- Integrates with Claude, Codex, Copilot, Cursor, Gemini, OpenCode

---

## 16. Format/Lint Integration

### Formatting (`nx format`)

- Uses **Prettier** under the hood
- `nx format:check` - Verify formatting compliance
- `nx format:write` - Apply formatting corrections
- Supports affected-based formatting (`--base`, `--head`)
- `--sort-root-tsconfig-paths` - Sort tsconfig compilerOptions.paths
- `--libs-and-apps` - Format only library and application files

### Linting

- Via `@nx/eslint` plugin
- Inferred `lint` targets from ESLint config files
- `@nx/eslint-plugin` provides `@nx/enforce-module-boundaries` rule
- Supports ESLint flat config and legacy `.eslintrc.json`

---

## 17. Watch Mode

### `nx watch`

- Monitor projects for file changes
- Execute arbitrary commands on change
- `--all` or `--projects=<names>` to specify scope
- `--includeDependentProjects` to watch dependencies too
- `--initialRun` to execute command once before watching
- Access `$NX_PROJECT_NAME` and `$NX_FILE_CHANGES` in commands

### Continuous Tasks (Nx 21+)

- `"continuous": true` on targets marks them as long-running
- Dependent tasks start without waiting for continuous tasks to complete
- Ideal for dev servers, watch-mode compilers

---

## 18. Batch & Local Distribution

### Batch Execution

- `--batch` flag on `nx run`, `nx run-many`, `nx affected`
- Sends tasks to executors in batches rather than one-by-one
- Executors must support batch processing
- Primary use: `@nx/gradle` plugin (sends tasks to Gradle in batches)

### Local Parallelism

- `--parallel=<N>` controls max concurrent processes
- `"parallelism": false` prevents specific tasks from running in parallel
- Default: 3 parallel processes

### No Built-In Local Distribution

Distributed task execution requires Nx Cloud / Nx Agents. However:
- Local parallelism fully supported
- `--batch` provides some bundling for compatible executors
- Custom `preTasksExecution`/`postTasksExecution` hooks can implement custom distribution logic

---

## 19. Environment Variable & Runtime Inputs

### Environment Variable Inputs

```jsonc
{
  "inputs": [
    { "env": "NODE_ENV" },
    { "env": "MY_API_KEY" },
    { "env": "CI" }
  ]
}
```

- Hash the value of specified environment variables
- Changes to the variable value invalidate the cache

### Runtime Inputs

```jsonc
{
  "inputs": [
    { "runtime": "node --version" },
    { "runtime": "echo $HOSTNAME" },
    { "runtime": "npx my-tool --version" }
  ]
}
```

- Execute a command and hash the stdout
- Useful for tool versions, system-dependent values

### Key Environment Variables (Nx Configuration)

| Variable | Purpose |
|----------|---------|
| `NX_DAEMON` | Enable/disable daemon (`true`/`false`) |
| `NX_DAEMON_SOCKET_DIR` | Custom daemon socket directory |
| `NX_MAX_CACHE_SIZE` | Override maxCacheSize |
| `NX_CLOUD_ENCRYPTION_KEY` | Cloud cache encryption key |
| `NX_SELF_HOSTED_REMOTE_CACHE_SERVER` | Custom cache server URL |
| `NX_SELF_HOSTED_REMOTE_CACHE_ACCESS_TOKEN` | Cache server auth token |
| `NX_FORMAT_SORT_TSCONFIG_PATHS` | Sort tsconfig paths in format |
| `NODE_TLS_REJECT_UNAUTHORIZED` | TLS validation for cache server |
| `NX_SKIP_NX_CACHE` | Skip cache for current run |
| `NX_VERBOSE_LOGGING` | Enable verbose logging |

---

## 20. External Dependency Hashing

### Specific External Dependencies

```jsonc
{
  "inputs": [
    { "externalDependencies": ["vite", "webpack", "typescript"] }
  ]
}
```

- Hash versions of specific npm packages
- Only changes to listed packages invalidate cache
- More precise than hashing all dependencies

### Default Behavior

- By default, Nx includes versions of all external dependencies in the hash
- `externalDependencies` input narrows this to specific packages
- Useful for tasks that only depend on certain tools

---

## 21. Sync Generators

### Purpose

Maintain repository integrity by using the project graph to update configuration files. Ensure files are in sync before tasks run.

### Two Categories

| Type | Trigger | Example |
|------|---------|---------|
| **Task Sync Generators** | Automatically before associated tasks | TypeScript project references |
| **Global Sync Generators** | `nx sync` or `nx sync:check` commands | CI pipeline config |

### Configuration

```jsonc
// nx.json
{
  "sync": {
    "applyChanges": true,       // auto-apply on dev machines
    "globalGenerators": ["@nx/js:typescript-sync"],
    "generatorOptions": {
      "@nx/js:typescript-sync": { /* options */ }
    },
    "disabledTaskSyncGenerators": ["@nx/some:generator"]
  }
}

// project.json target
{
  "targets": {
    "build": {
      "syncGenerators": ["@nx/js:typescript-sync"]
    }
  }
}
```

### Behavior

- **Dev machines**: Task sync generators run in `--dry-run` mode; prompt to apply
- **CI**: Sync generators run in `--dry-run` mode; **fail** if changes would occur
- **`--skip-sync`**: Skip sync processing on task execution

### Commands

- `nx sync` - Execute all sync generators
- `nx sync:check` - Check if changes needed (CI-appropriate, fast-fail)

### Best Practices

- Add `nx sync:check` at start of CI pipeline
- Use `nx sync` in pre-commit/pre-push git hooks
- Most sync generators registered automatically via inference plugins

---

## 22. Terminal UI (TUI)

### Overview (Nx 21+)

Interactive terminal interface for viewing multi-task execution.

### Features

- **Task list panel** - Shows all running/completed tasks
- **Log output panel** - Displays selected task's output
- **Side-by-side view** - Display multiple tasks simultaneously
- **Navigation** - Arrow keys or Vim-style h/j/k/l
- **Search/filter** - Search through task list
- **Keyboard shortcuts** - `?` for help, `q` to exit
- **Built with Ratatui** (Rust TUI library)

### Configuration

```jsonc
// nx.json
{
  "tui": {
    "enabled": true,
    "autoExit": true  // true, false, or number of seconds (default: 3 seconds)
  }
}
```

### CLI Overrides

- `--tui` / `--tui=false` - Enable/disable per command
- `--tuiAutoExit` - Override auto-exit behavior
- `--outputStyle=tui` - Explicitly select TUI output

### Output Styles

| Style | Description |
|-------|-------------|
| `tui` | Interactive Terminal UI (default in Nx 21+) |
| `dynamic` | Animated progress display |
| `dynamic-legacy` | Legacy animated display |
| `static` | Plain text output |
| `stream` | Stream output with project prefixes |
| `stream-without-prefixes` | Stream output without prefixes |

### Environment Behavior

- Enabled by default for interactive terminals
- Disabled in CI environments automatically
- Windows support added in Nx 22.1

---

## 23. Powerpack Features

### Current Status (as of 2026)

Nx Powerpack is no longer a standalone product. Self-hosted caching is **free for everyone**. Conformance and Owners are included in the Enterprise plan.

### Self-Hosted Remote Cache (FREE)

- Custom cache server via OpenAPI spec (Nx 20.8+)
- Environment variable configuration
- Official adapters: S3, GCS, Azure, Shared Filesystem
- **CREEP vulnerability warning** (CVE-2025-36852) for bucket-based caches

### Conformance (Enterprise)

- Define and enforce workspace-wide rules
- Built-in rules: project boundaries, ensure owners
- Custom rule development
- Rule status: enforced, evaluated, disabled
- Upload custom rules to Nx Cloud for multi-repo enforcement

### Codeowners (Enterprise)

- Automatic CODEOWNERS file synchronization
- Supports GitHub, GitLab, Bitbucket formats
- Define owners in nx.json at project level or via tags
- `@nx/conformance/ensure-owners` rule enforces ownership

---

## 24. AI Agent Integration

### `nx configure-ai-agents`

Set up AI agent configurations for:
- Claude
- Codex
- Copilot
- Cursor
- Gemini
- OpenCode

### `nx init --aiAgents`

Initialize workspace with AI agent support.

### `nx mcp`

MCP server for providing workspace context to AI tools.

### Features

- Workspace-level context for AI coding assistants
- Project graph and task information exposure
- Up-to-date documentation integration
- Configuration check/validation (`--check`)

---

## 25. Official Plugins

### Frameworks & Libraries

| Plugin | Description |
|--------|-------------|
| `@nx/angular` | Angular apps/libs with Storybook, Jest, ESLint, Tailwind, Cypress, Playwright, NgRx, Module Federation |
| `@nx/react` | React apps/libs with Jest, Vitest, Playwright, Cypress, Storybook |
| `@nx/next` | Next.js applications |
| `@nx/node` | Node.js applications |
| `@nx/nest` | NestJS applications |
| `@nx/express` | Express applications |
| `@nx/remix` | Remix applications |
| `@nx/vue` | Vue applications |
| `@nx/nuxt` | Nuxt applications |
| `@nx/expo` | Expo mobile applications |
| `@nx/react-native` | React Native mobile applications |

### Build Tools

| Plugin | Description |
|--------|-------------|
| `@nx/vite` | Vite integration |
| `@nx/webpack` | Webpack integration |
| `@nx/esbuild` | esbuild integration |
| `@nx/rollup` | Rollup integration |
| `@nx/rspack` | Rspack integration |
| `@nx/rsbuild` | Rsbuild integration |

### Testing

| Plugin | Description |
|--------|-------------|
| `@nx/jest` | Jest testing |
| `@nx/vitest` | Vitest testing (standalone from Nx 22) |
| `@nx/cypress` | Cypress E2E testing |
| `@nx/playwright` | Playwright E2E testing |
| `@nx/storybook` | Storybook integration |
| `@nx/detox` | Detox mobile E2E testing |

### Other

| Plugin | Description |
|--------|-------------|
| `@nx/js` | JavaScript/TypeScript project support |
| `@nx/eslint` | ESLint integration |
| `@nx/eslint-plugin` | ESLint rules including enforce-module-boundaries |
| `@nx/docker` | Docker containerization |
| `@nx/dotnet` | .NET project graph support |
| `@nx/gradle` | Gradle/Java/Kotlin support with batch execution |
| `@nx/module-federation` | Module Federation support |
| `@nx/plugin` | Plugin development toolkit |

### Powerpack Packages

| Plugin | Description |
|--------|-------------|
| `@nx/s3-cache` | S3 remote cache |
| `@nx/gcs-cache` | GCS remote cache |
| `@nx/azure-cache` | Azure remote cache |
| `@nx/shared-fs-cache` | Shared filesystem cache |
| `@nx/conformance` | Conformance rules |
| `@nx/owners` | Codeowners management |

---

## Appendix: Built-in Executors

| Executor | Description |
|----------|-------------|
| `nx:run-commands` | Run arbitrary shell commands (shorthand: `command` property) |
| `nx:run-script` | Run a package.json script |
| `nx:noop` | No-op executor (useful for targets that only have dependsOn) |

---

## Appendix: Key Nx Devkit APIs

| API | Purpose |
|-----|---------|
| `Tree` | Virtual filesystem for atomic file operations |
| `addProjectConfiguration` | Add project to workspace |
| `readProjectConfiguration` | Read project config |
| `updateProjectConfiguration` | Update project config |
| `readNxJson` | Read nx.json |
| `updateNxJson` | Update nx.json |
| `generateFiles` | Copy templates with variable substitution |
| `formatFiles` | Format generated files |
| `installPackagesTask` | Install dependencies |
| `getProjects` | List all projects |
| `createProjectGraphAsync` | Get project graph |
| `readTargetOptions` | Read resolved target options |
| `parseTargetString` | Parse "project:target:config" string |
| `joinPathFragments` | Join path segments |
| `workspaceRoot` | Get workspace root path |
| `logger` | Logging utility |
| `output` | Formatted output utility |
