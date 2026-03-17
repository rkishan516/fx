import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';

import '../output/output_formatter.dart';

/// `fx report` — Output system info for bug reports.
class ReportCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'report';

  @override
  String get description =>
      'Print environment and workspace info for bug reports.';

  ReportCommand({required this.formatter});

  @override
  Future<void> run() async {
    final env = Environment.toJson();

    formatter.writeln('fx Report');
    formatter.writeln('=' * 40);
    formatter.writeln('');

    // fx version
    formatter.writeln('fx version       : 0.1.0');
    formatter.writeln('Dart version     : ${env['dartVersion']}');
    formatter.writeln('Platform         : ${env['platform']}');
    formatter.writeln(
      'CI               : ${env['isCI'] == true ? 'yes (${Environment.ciProvider ?? 'unknown'})' : 'no'}',
    );
    formatter.writeln('Color support    : ${env['useColor']}');
    formatter.writeln('Interactive      : ${env['isInteractive']}');
    formatter.writeln('Concurrency      : ${env['concurrency']}');
    formatter.writeln('');

    // Workspace info
    try {
      final workspace = await WorkspaceLoader.load(Directory.current.path);
      formatter.writeln('Workspace');
      formatter.writeln('-' * 40);
      formatter.writeln('Root             : ${workspace.rootPath}');
      formatter.writeln('Projects         : ${workspace.projects.length}');
      formatter.writeln(
        'Package patterns : ${workspace.config.packages.join(', ')}',
      );

      final targetNames = <String>{};
      for (final p in workspace.projects) {
        targetNames.addAll(p.targets.keys);
      }
      formatter.writeln('Targets          : ${targetNames.join(', ')}');

      formatter.writeln(
        'Cache enabled    : ${workspace.config.cacheConfig.enabled}',
      );
      if (workspace.config.cacheConfig.remoteUrl != null) {
        formatter.writeln(
          'Remote cache     : ${workspace.config.cacheConfig.remoteUrl}',
        );
      }

      // Generators
      if (workspace.config.generators.isNotEmpty) {
        formatter.writeln(
          'Plugins          : ${workspace.config.generators.join(', ')}',
        );
      }
    } on FxException {
      formatter.writeln(
        'Workspace        : not found (not inside an fx workspace)',
      );
    }
  }
}
