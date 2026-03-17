/// Performs simple mustache-style variable substitution in template strings.
///
/// Replaces `{{variable_name}}` placeholders with values from a provided map.
/// Unknown variables are left as-is.
class TemplateEngine {
  const TemplateEngine();

  /// Returns [template] with all `{{key}}` occurrences replaced by their
  /// corresponding values in [variables].
  String render(String template, Map<String, String> variables) {
    if (template.isEmpty || variables.isEmpty) return template;

    var result = template;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
}
