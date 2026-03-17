/// Base exception class for all fx errors.
class FxException implements Exception {
  final String message;
  final String? hint;

  const FxException(this.message, {this.hint});

  @override
  String toString() {
    if (hint != null) {
      return 'FxException: $message\nHint: $hint';
    }
    return 'FxException: $message';
  }
}

/// Thrown when a workspace cannot be found.
class WorkspaceNotFoundException extends FxException {
  const WorkspaceNotFoundException(String path)
    : super(
        'No fx workspace found at or above: $path',
        hint:
            'Run `fx init` to create a new workspace, or navigate to a directory within an fx workspace.',
      );
}

/// Thrown when configuration is invalid.
class ConfigException extends FxException {
  const ConfigException(super.message, {super.hint});
}
