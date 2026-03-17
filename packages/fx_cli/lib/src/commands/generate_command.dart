import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_generator/fx_generator.dart';
import 'package:path/path.dart' as p;

import '../output/output_formatter.dart';

/// Abstraction for reading user input (allows test injection).
class Prompter {
  final StringSink _sink;
  final Stream<String> _input;

  Prompter({required StringSink sink, required Stream<String> input})
    : _sink = sink,
      _input = input;

  factory Prompter.stdio() => Prompter(
    sink: stdout,
    input: stdin
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter()),
  );

  Future<String> prompt(String message) async {
    _sink.write('$message: ');
    return await _input.first;
  }

  Future<int> choose(String message, List<String> options) async {
    _sink.writeln(message);
    for (var i = 0; i < options.length; i++) {
      _sink.writeln('  ${i + 1}) ${options[i]}');
    }
    _sink.write('Choice [1-${options.length}]: ');
    final answer = await _input.first;
    final index = int.tryParse(answer.trim());
    if (index == null || index < 1 || index > options.length) {
      return 0; // Default to first
    }
    return index - 1;
  }
}

/// `fx generate <generator> <name>` — Scaffold a new project.
class GenerateCommand extends Command<void> {
  final OutputFormatter formatter;
  final Prompter? prompter;

  @override
  String get name => 'generate';

  @override
  String get description =>
      'Scaffold a new app, package, or plugin using a generator.';

  GenerateCommand({required this.formatter, this.prompter}) {
    argParser
      ..addOption(
        'directory',
        abbr: 'd',
        help: 'Output directory (defaults to packages/).',
      )
      ..addFlag(
        'dry-run',
        help: 'Show what files would be generated without writing.',
        negatable: false,
      )
      ..addFlag('list', help: 'List available generators.', negatable: false)
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Interactively prompt for generator and name.',
        negatable: false,
      )
      ..addFlag(
        'no-interactive',
        help:
            'Disable interactive prompts (CI mode). '
            'Errors on missing required parameters.',
        negatable: false,
      )
      ..addOption(
        'workspace',
        help: 'Path to workspace root (for testing).',
        hide: true,
      );
  }

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] as bool;
    final listGenerators = argResults!['list'] as bool;
    final workspacePath = argResults!['workspace'] as String?;

    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    final registry = GeneratorRegistry.withBuiltIns();

    // Discover plugin generators from configured paths
    if (workspace.config.generators.isNotEmpty) {
      final loader = GeneratorPluginLoader(
        pluginPaths: workspace.config.generators,
      );
      final plugins = await loader.discover();
      for (final plugin in plugins) {
        registry.register(plugin);
      }
    }

    if (listGenerators) {
      formatter.writeln('Available generators:');
      for (final gen in registry.all) {
        formatter.writeln('  ${gen.name.padRight(24)} ${gen.description}');
      }
      return;
    }

    final rest = argResults!.rest;
    final interactive = argResults!['interactive'] as bool;

    String generatorName;
    String projectName;

    if (rest.length >= 2) {
      generatorName = rest[0];
      projectName = rest[1];
    } else if (interactive && prompter != null) {
      final generators = registry.all.toList();
      final index = await prompter!.choose(
        'Select a generator:',
        generators.map((g) => g.name).toList(),
      );
      generatorName = generators[index].name;
      projectName = await prompter!.prompt('Project name');
    } else {
      throw UsageException(
        'Usage: fx generate <generator> <name>\n'
        'Or use --interactive for guided prompts.',
        usage,
      );
    }
    final dirArg = argResults!['directory'] as String?;

    final generator = registry.get(generatorName);
    if (generator == null) {
      throw UsageException(
        'Unknown generator: "$generatorName". '
        'Run `fx generate --list` to see available generators.',
        usage,
      );
    }

    final outputDir = dirArg != null
        ? p.join(dirArg, projectName)
        : p.join(workspace.rootPath, 'packages', projectName);

    // Collect generator-specific variables via prompts
    var variables = <String, String>{};
    final noInteractive = argResults!['no-interactive'] as bool;

    if (generator.prompts.isNotEmpty) {
      if (!noInteractive && interactive && prompter != null) {
        final runner = PromptRunner(
          output: stderr,
          input: stdin
              .transform(const SystemEncoding().decoder)
              .transform(const LineSplitter()),
        );
        variables = await runner.run(
          prompts: generator.prompts,
          providedVariables: variables,
        );
      }

      if (noInteractive) {
        final missing = PromptRunner.validateRequired(
          prompts: generator.prompts,
          variables: variables,
        );
        if (missing.isNotEmpty) {
          throw UsageException(
            'Missing required parameters: ${missing.join(', ')}. '
            'Use --interactive or provide values via options.',
            usage,
          );
        }
      }
    }

    final ctx = GeneratorContext(
      projectName: projectName,
      outputDirectory: outputDir,
      variables: variables,
    );

    final files = await generator.generate(ctx);

    if (dryRun) {
      formatter.writeln(
        'Would generate ${files.length} files for $projectName:',
      );
      for (final f in files) {
        formatter.writeln('  ${p.join(outputDir, f.relativePath)}');
      }
      return;
    }

    // Write files to disk
    for (final f in files) {
      final filePath = p.join(outputDir, f.relativePath);
      final file = File(filePath);
      if (!f.overwrite && file.existsSync()) continue;
      FileUtils.writeFile(filePath, f.content);
    }

    formatter.writeln(
      'Generated "$projectName" with ${files.length} files at $outputDir',
    );
  }

  String _findWorkspaceRoot() {
    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }
    return root;
  }
}
