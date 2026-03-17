import 'dart:async';

import 'generator_prompt.dart';

/// Runs interactive prompts for generator parameters not provided via CLI.
///
/// Reads from [input] and writes to [output] (stderr by default to keep
/// stdout clean for piping).
class PromptRunner {
  final StringSink output;
  final Stream<String> input;

  PromptRunner({required this.output, required this.input});

  /// Prompts for any parameters in [prompts] not already present in
  /// [providedVariables].
  ///
  /// Returns a merged map with prompted values added to provided ones.
  Future<Map<String, String>> run({
    required List<GeneratorPrompt> prompts,
    required Map<String, String> providedVariables,
  }) async {
    final result = Map<String, String>.from(providedVariables);
    final iterator = StreamIterator(input);

    try {
      for (final prompt in prompts) {
        if (result.containsKey(prompt.name)) continue;

        final value = switch (prompt.type) {
          PromptType.text => await _promptText(prompt, iterator),
          PromptType.confirm => await _promptConfirm(prompt, iterator),
          PromptType.select => await _promptSelect(prompt, iterator),
        };

        if (value != null) {
          result[prompt.name] = value;
        } else if (prompt.defaultValue != null) {
          result[prompt.name] = prompt.defaultValue!;
        }
      }
    } finally {
      await iterator.cancel();
    }

    return result;
  }

  /// Validates that all required parameters are present.
  ///
  /// Returns list of missing required parameter names.
  static List<String> validateRequired({
    required List<GeneratorPrompt> prompts,
    required Map<String, String> variables,
  }) {
    final missing = <String>[];
    for (final prompt in prompts) {
      if (prompt.required && !variables.containsKey(prompt.name)) {
        missing.add(prompt.name);
      }
    }
    return missing;
  }

  Future<String> _readLine(StreamIterator<String> iterator) async {
    if (await iterator.moveNext()) return iterator.current;
    return '';
  }

  Future<String?> _promptText(
    GeneratorPrompt prompt,
    StreamIterator<String> iterator,
  ) async {
    final defaultHint = prompt.defaultValue != null
        ? ' [${prompt.defaultValue}]'
        : '';
    output.write('${prompt.message}$defaultHint: ');
    final answer = await _readLine(iterator);
    final trimmed = answer.trim();
    return trimmed.isEmpty ? prompt.defaultValue : trimmed;
  }

  Future<String?> _promptConfirm(
    GeneratorPrompt prompt,
    StreamIterator<String> iterator,
  ) async {
    final defaultHint = prompt.defaultValue == 'true' ? ' [Y/n]' : ' [y/N]';
    output.write('${prompt.message}$defaultHint: ');
    final answer = (await _readLine(iterator)).trim().toLowerCase();
    if (answer.isEmpty) return prompt.defaultValue ?? 'false';
    return (answer == 'y' || answer == 'yes') ? 'true' : 'false';
  }

  Future<String?> _promptSelect(
    GeneratorPrompt prompt,
    StreamIterator<String> iterator,
  ) async {
    final choices = prompt.choices ?? [];
    if (choices.isEmpty) return prompt.defaultValue;

    output.writeln(prompt.message);
    for (var i = 0; i < choices.length; i++) {
      final marker = choices[i] == prompt.defaultValue ? ' (default)' : '';
      output.writeln('  ${i + 1}) ${choices[i]}$marker');
    }
    output.write('Choice [1-${choices.length}]: ');
    final answer = (await _readLine(iterator)).trim();
    final index = int.tryParse(answer);
    if (index != null && index >= 1 && index <= choices.length) {
      return choices[index - 1];
    }
    return prompt.defaultValue ?? choices.first;
  }
}
