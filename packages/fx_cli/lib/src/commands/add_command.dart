import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

import '../output/output_formatter.dart';
import 'run_command.dart';

/// `fx add <package>` — Install a plugin and register it.
class AddCommand extends Command<void> {
  final OutputFormatter formatter;
  final ProcessRunner processRunner;

  @override
  String get name => 'add';

  @override
  String get description =>
      'Install a plugin and register it in the workspace.';

  AddCommand({required this.formatter, required this.processRunner}) {
    argParser.addFlag('dev', help: 'Add as dev dependency.', negatable: false);
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw UsageException('Missing package name.', usage);
    }
    final packageName = rest.first;
    final isDev = argResults!['dev'] as bool;

    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }

    // Run dart pub add
    final args = ['pub', 'add', packageName];
    if (isDev) args.add('--dev');

    formatter.writeln('Installing $packageName...');
    final result = await processRunner.run(
      ProcessCall(executable: 'dart', arguments: args, workingDirectory: root),
    );

    if (result.exitCode != 0) {
      formatter.writeln('Failed to install $packageName:');
      formatter.writeln(result.stderr);
      throw ProcessExit(1);
    }

    // Register in fx: generators list if it looks like a generator plugin
    if (packageName.contains('generator') || packageName.contains('plugin')) {
      _registerPlugin(root, packageName);
      formatter.writeln('Registered $packageName as an fx plugin.');
    }

    formatter.writeln('Successfully added $packageName.');
  }

  void _registerPlugin(String root, String packageName) {
    final pubspecPath = p.join(root, 'pubspec.yaml');
    final content = File(pubspecPath).readAsStringSync();
    final editor = YamlEditor(content);

    try {
      // Try to append to existing generators list
      final existing = editor.parseAt(['fx', 'generators']);
      if (existing.value is List) {
        final list = (existing.value as List).cast<dynamic>();
        if (!list.contains(packageName)) {
          editor.appendToList(['fx', 'generators'], packageName);
        }
      }
    } catch (_) {
      // If fx.generators doesn't exist, try to create it
      try {
        editor.update(['fx', 'generators'], [packageName]);
      } catch (_) {
        // fx section may not exist — skip registration
        return;
      }
    }

    File(pubspecPath).writeAsStringSync(editor.toString());
  }
}
