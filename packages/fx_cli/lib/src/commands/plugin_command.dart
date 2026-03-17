import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_generator/fx_generator.dart';

import '../output/output_formatter.dart';

/// `fx plugin list` — List available and installed generator plugins.
class PluginCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'plugin';

  @override
  String get description => 'Manage generator plugins.';

  PluginCommand({required this.formatter}) {
    addSubcommand(_PluginListCommand(formatter: formatter));
  }
}

class _PluginListCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'list';

  @override
  String get description => 'List available and installed generator plugins.';

  _PluginListCommand({required this.formatter}) {
    argParser.addOption(
      'workspace',
      help: 'Path to workspace root (for testing).',
      hide: true,
    );
  }

  @override
  Future<void> run() async {
    final workspacePath = argResults!['workspace'] as String?;
    final root =
        workspacePath ?? FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }

    final workspace = await WorkspaceLoader.load(root);
    final registry = GeneratorRegistry.withBuiltIns();

    formatter.writeln('Built-in generators:');
    for (final gen in registry.all) {
      formatter.writeln('  ${gen.name.padRight(24)} ${gen.description}');
    }

    // Show hook plugins (PluginConfig with capabilities)
    if (workspace.config.pluginConfigs.isNotEmpty) {
      formatter.writeln('');
      formatter.writeln('Configured hook plugins:');
      for (final pc in workspace.config.pluginConfigs) {
        final capStr = pc.capabilities.isEmpty
            ? ''
            : ' [${pc.capabilities.map((c) => c.name).join(', ')}]';
        final priorityStr = pc.priority != 0
            ? ' (priority: ${pc.priority})'
            : '';
        formatter.writeln('  ${pc.plugin}$capStr$priorityStr');
      }
    }

    if (workspace.config.generators.isNotEmpty) {
      formatter.writeln('');
      formatter.writeln('Configured plugin paths:');
      for (final path in workspace.config.generators) {
        formatter.writeln('  $path');
      }

      final loader = GeneratorPluginLoader(
        pluginPaths: workspace.config.generators,
      );
      final plugins = await loader.discover();
      if (plugins.isNotEmpty) {
        formatter.writeln('');
        formatter.writeln('Installed plugins:');
        for (final plugin in plugins) {
          formatter.writeln(
            '  ${plugin.name.padRight(24)} ${plugin.description}',
          );
        }
      }
    } else {
      formatter.writeln('');
      formatter.writeln('No plugin paths configured.');
      formatter.writeln(
        'Add generator plugin paths under fx.generators in pubspec.yaml.',
      );
    }
  }
}
