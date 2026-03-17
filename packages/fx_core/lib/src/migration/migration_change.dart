/// Type of change a migration will apply.
enum MigrationChangeType {
  /// Modify an existing file's contents.
  modify,

  /// Create a new file.
  create,

  /// Delete an existing file.
  delete,

  /// Rename/move a file.
  rename,
}

/// A single file change proposed or applied by a migration.
class MigrationChange {
  /// The type of change.
  final MigrationChangeType type;

  /// Relative path (from workspace root) of the affected file.
  final String filePath;

  /// Human-readable description of the change.
  final String description;

  /// Content before the change (for [MigrationChangeType.modify]).
  final String? before;

  /// Content after the change (for [MigrationChangeType.modify] or [MigrationChangeType.create]).
  final String? after;

  const MigrationChange({
    required this.type,
    required this.filePath,
    required this.description,
    this.before,
    this.after,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'filePath': filePath,
    'description': description,
    if (before != null) 'before': before,
    if (after != null) 'after': after,
  };

  factory MigrationChange.fromJson(Map<String, dynamic> json) {
    return MigrationChange(
      type: MigrationChangeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MigrationChangeType.modify,
      ),
      filePath: json['filePath'] as String,
      description: json['description'] as String,
      before: json['before'] as String?,
      after: json['after'] as String?,
    );
  }

  @override
  String toString() => 'MigrationChange($type, $filePath)';
}
