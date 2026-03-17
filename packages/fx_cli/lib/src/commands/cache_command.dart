import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_cache/fx_cache.dart';
import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;

import '../output/output_formatter.dart';

/// `fx cache` — Manage the computation cache.
///
/// Subcommands: `clear`, `status`
class CacheCommand extends Command<void> {
  @override
  String get name => 'cache';

  @override
  String get description => 'Manage the fx computation cache.';

  CacheCommand({required OutputFormatter formatter, String? cacheDir}) {
    addSubcommand(CacheClearCommand(formatter: formatter, cacheDir: cacheDir));
    addSubcommand(CacheStatusCommand(formatter: formatter, cacheDir: cacheDir));
  }
}

/// `fx cache clear` — Remove all cached entries.
class CacheClearCommand extends Command<void> {
  final OutputFormatter formatter;
  final String? cacheDir;

  @override
  String get name => 'clear';

  @override
  String get description => 'Remove all cached task results.';

  CacheClearCommand({required this.formatter, this.cacheDir}) {
    argParser.addOption(
      'workspace',
      help: 'Path to workspace root (for testing).',
      hide: true,
    );
  }

  @override
  Future<void> run() async {
    final workspacePath = argResults!['workspace'] as String?;
    final effectiveCacheDir = cacheDir ?? await _resolveCacheDir(workspacePath);

    final store = LocalCacheStore(cacheDir: effectiveCacheDir);
    await store.clear();
    formatter.writeln('Cache cleared: $effectiveCacheDir');
  }

  Future<String> _resolveCacheDir(String? workspacePath) async {
    try {
      final workspace = await WorkspaceLoader.load(
        workspacePath ?? _findWorkspaceRoot(),
      );
      return p.join(workspace.rootPath, workspace.config.cacheConfig.directory);
    } catch (_) {
      return p.join(Directory.current.path, '.fx_cache');
    }
  }

  String _findWorkspaceRoot() {
    return FileUtils.findWorkspaceRoot(Directory.current.path) ??
        Directory.current.path;
  }
}

/// `fx cache status` — Show cache statistics.
class CacheStatusCommand extends Command<void> {
  final OutputFormatter formatter;
  final String? cacheDir;

  @override
  String get name => 'status';

  @override
  String get description => 'Show cache statistics (entry count, size).';

  CacheStatusCommand({required this.formatter, this.cacheDir}) {
    argParser.addOption(
      'workspace',
      help: 'Path to workspace root (for testing).',
      hide: true,
    );
  }

  @override
  Future<void> run() async {
    final workspacePath = argResults!['workspace'] as String?;
    final effectiveCacheDir = cacheDir ?? await _resolveCacheDir(workspacePath);

    final dir = Directory(effectiveCacheDir);
    if (!dir.existsSync()) {
      formatter.writeln('Cache directory not found: $effectiveCacheDir');
      formatter.writeln('Entries: 0 | Total size: 0 bytes');
      return;
    }

    final files = dir.listSync().whereType<File>().toList();
    final totalBytes = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    final kb = (totalBytes / 1024).toStringAsFixed(1);

    formatter.writeln('Cache directory: $effectiveCacheDir');
    formatter.writeln('Entries: ${files.length} | Total size: $kb KB');
  }

  Future<String> _resolveCacheDir(String? workspacePath) async {
    try {
      final workspace = await WorkspaceLoader.load(
        workspacePath ?? _findWorkspaceRoot(),
      );
      return p.join(workspace.rootPath, workspace.config.cacheConfig.directory);
    } catch (_) {
      return p.join(Directory.current.path, '.fx_cache');
    }
  }

  String _findWorkspaceRoot() {
    return FileUtils.findWorkspaceRoot(Directory.current.path) ??
        Directory.current.path;
  }
}
