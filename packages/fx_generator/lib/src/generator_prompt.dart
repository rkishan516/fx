/// Type of interactive prompt.
enum PromptType {
  /// Free-text input.
  text,

  /// Yes/no confirmation.
  confirm,

  /// Single selection from a list of choices.
  select,
}

/// Describes an interactive prompt for a generator parameter.
///
/// Generators declare prompts for their required parameters. When running
/// interactively, missing parameters are prompted for via stdin.
class GeneratorPrompt {
  /// Parameter name (matches the key in [GeneratorContext.variables]).
  final String name;

  /// Human-readable prompt message shown to the user.
  final String message;

  /// The type of prompt interaction.
  final PromptType type;

  /// Default value (used when user presses Enter without input).
  final String? defaultValue;

  /// Available choices for [PromptType.select].
  final List<String>? choices;

  /// Whether this parameter is required.
  final bool required;

  const GeneratorPrompt({
    required this.name,
    required this.message,
    this.type = PromptType.text,
    this.defaultValue,
    this.choices,
    this.required = true,
  });
}
