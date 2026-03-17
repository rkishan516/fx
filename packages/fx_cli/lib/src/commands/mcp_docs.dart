/// Embedded documentation sections for the `fx_docs` MCP tool.
const fxDocSections = [
  {
    'title': 'fx init',
    'content':
        'Initialize a new fx workspace. Creates a root pubspec.yaml '
        'with workspace configuration including package globs, default '
        'targets (test, analyze, format), and cache settings. '
        'Usage: fx init [name] [--directory=<dir>]',
  },
  {
    'title': 'fx generate',
    'content':
        'Scaffold new projects using generators. Built-in generators: '
        'dart_package, flutter_package, flutter_app, dart_cli, '
        'add_dependency, rename_package, move_package. '
        'Usage: fx generate <generator> <name> [--directory=<dir>] [--dry-run]',
  },
  {
    'title': 'fx run',
    'content':
        'Run a target on a specific project. Resolves the executor '
        'from project, workspace, or targetDefaults config. Supports '
        'local caching to skip unchanged tasks. '
        'Usage: fx run <project> <target> [--skip-cache] [--verbose]',
  },
  {
    'title': 'fx run-many',
    'content':
        'Run a target across multiple projects in parallel with '
        'topological ordering. Respects dependency graph for execution '
        'order. Supports --projects glob, --exclude, --concurrency. '
        'Usage: fx run-many --target=<target> [--projects=<glob>] '
        '[--exclude=<glob>] [--concurrency=<n>]',
  },
  {
    'title': 'fx affected',
    'content':
        'Run a target only on projects affected by changes since a '
        'git ref. Uses the project dependency graph to determine which '
        'projects are impacted. '
        'Usage: fx affected --target=<target> [--base=<ref>] [--head=HEAD]',
  },
  {
    'title': 'fx graph',
    'content':
        'Visualize the project dependency graph. Outputs as text '
        'tree, JSON (nodes + edges), or DOT format for Graphviz. '
        'Usage: fx graph [--format=text|json|dot] [--web] [--port=<port>]',
  },
  {
    'title': 'fx list',
    'content':
        'List all projects in the workspace with their types and '
        'paths. Supports text and JSON output. '
        'Usage: fx list [--format=text|json]',
  },
  {
    'title': 'fx cache',
    'content':
        'Manage the local computation cache. Subcommands: status '
        '(show cache info), clear (remove cached entries). The cache '
        'hashes source files, dependencies, and config to skip unchanged '
        'tasks. Default directory: .fx_cache. '
        'Usage: fx cache status | fx cache clear',
  },
  {
    'title': 'Workspace Configuration',
    'content':
        'fx reads configuration from the root pubspec.yaml under '
        'the "fx" key. Fields: packages (glob patterns for project '
        'discovery), targets (workspace-level target definitions), '
        'targetDefaults (default settings for targets), cache (enabled, '
        'directory), namedInputs (reusable input patterns), defaultBase '
        '(git ref for affected analysis), generators (paths to custom '
        'generator packages), moduleBoundaries (enforce import rules '
        'between tagged projects).',
  },
  {
    'title': 'Targets and Executors',
    'content':
        'Targets define tasks that can be run on projects. Each '
        'target has an executor (shell command), optional inputs/outputs '
        'for caching, and dependsOn for task pipelines. Targets are '
        'resolved by merging: targetDefaults < workspace targets < '
        'project-level targets. Auto-inferred targets: test (if test/ '
        'exists), analyze (if analysis_options.yaml exists), format '
        '(if lib/ exists), compile (if bin/ exists).',
  },
  {
    'title': 'Project Types',
    'content':
        'fx supports three project types: app (applications with '
        'executables), package (reusable libraries), plugin (Flutter '
        'plugins). Type is inferred from pubspec.yaml: flutter plugin '
        'class → plugin, executables or bin/ → app, otherwise package.',
  },
  {
    'title': 'fx bootstrap',
    'content':
        'Run pub get across all workspace packages in topological '
        'order. Ensures path dependencies are resolved correctly. '
        'Usage: fx bootstrap [--concurrency=<n>]',
  },
  {
    'title': 'fx show',
    'content':
        'Show detailed information about a project including its '
        'type, path, dependencies, dependents, tags, and targets. '
        'Usage: fx show <project> [--format=text|json] or fx show (lists all)',
  },
  {
    'title': 'fx mcp',
    'content':
        'Start an MCP (Model Context Protocol) server over stdio. '
        'Exposes workspace tools to AI coding assistants via JSON-RPC 2.0. '
        'Tools include project listing, graph, details, generators, docs, '
        'and task monitoring. Usage: fx mcp',
  },
  {
    'title': 'fx configure-ai-agents',
    'content':
        'Generate workspace-aware configuration files for AI coding '
        'assistants. Supports Claude, Cursor, Windsurf, Copilot, Aider, '
        'and Cline. Writes context about workspace structure, projects, '
        'and targets. Usage: fx configure-ai-agents [--agents=<list>] '
        '[--check]',
  },
];
