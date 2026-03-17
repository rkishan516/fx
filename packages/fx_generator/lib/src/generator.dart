import 'generator_prompt.dart';

/// Context passed to a generator when running code generation.
class GeneratorContext {
  final String projectName;
  final String outputDirectory;
  final Map<String, String> variables;

  const GeneratorContext({
    required this.projectName,
    required this.outputDirectory,
    Map<String, String>? variables,
  }) : variables = variables ?? const {};
}

/// A single file to be written by a generator.
class GeneratedFile {
  final String relativePath;
  final String content;

  /// Whether to overwrite an existing file at this path.
  final bool overwrite;

  const GeneratedFile({
    required this.relativePath,
    required this.content,
    this.overwrite = false,
  });
}

/// Base class for all code generators (built-in and plugin).
abstract class Generator {
  /// Unique identifier for this generator (e.g., "dart_package").
  String get name;

  /// Human-readable description shown in `fx generate --list`.
  String get description;

  /// Interactive prompts for parameters not provided via CLI flags.
  ///
  /// Override this to declare parameters that can be prompted for
  /// interactively. Default: empty list (no prompts).
  List<GeneratorPrompt> get prompts => const [];

  /// Returns the list of files to create for [context].
  Future<List<GeneratedFile>> generate(GeneratorContext context);
}
