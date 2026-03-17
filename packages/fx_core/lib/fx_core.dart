/// Core models, configuration, and utilities for the fx monorepo tool.
library;

// Models
export 'src/models/project.dart';
export 'src/models/target.dart';
export 'src/models/workspace_config.dart';

// Utils
export 'src/utils/environment.dart';
export 'src/utils/fx_exception.dart';
export 'src/utils/pubspec_parser.dart';
export 'src/utils/logger.dart';
export 'src/utils/file_utils.dart';
export 'src/utils/ignore_parser.dart';
export 'src/utils/path_tokens.dart';

// Plugin
export 'src/plugin/plugin_hook.dart';
export 'src/plugin/plugin_loader.dart';

// Migration
export 'src/migration/migration_change.dart';
export 'src/migration/migration_generator.dart';
export 'src/migration/migration_registry.dart';

// Workspace
export 'src/workspace/workspace.dart';
export 'src/workspace/workspace_loader.dart';
export 'src/workspace/project_discovery.dart';
