/// A serializable record of a completed task's output, stored in the cache.
class CacheEntry {
  final String projectName;
  final String targetName;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  /// The SHA-256 hash of the inputs used to produce this result.
  final String inputHash;

  /// Cached output file artifacts: relative path → file content.
  /// Used to restore build directories from cache.
  final Map<String, String> outputArtifacts;

  const CacheEntry({
    required this.projectName,
    required this.targetName,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    required this.inputHash,
    this.outputArtifacts = const {},
  });

  bool get isSuccess => exitCode == 0;

  Map<String, dynamic> toJson() => {
    'projectName': projectName,
    'targetName': targetName,
    'exitCode': exitCode,
    'stdout': stdout,
    'stderr': stderr,
    'durationMs': duration.inMilliseconds,
    'inputHash': inputHash,
    if (outputArtifacts.isNotEmpty) 'outputArtifacts': outputArtifacts,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    projectName: json['projectName'] as String,
    targetName: json['targetName'] as String,
    exitCode: json['exitCode'] as int,
    stdout: json['stdout'] as String,
    stderr: json['stderr'] as String,
    duration: Duration(milliseconds: json['durationMs'] as int),
    inputHash: json['inputHash'] as String,
    outputArtifacts: json['outputArtifacts'] != null
        ? Map<String, String>.from(json['outputArtifacts'] as Map)
        : const {},
  );

  @override
  String toString() =>
      'CacheEntry($projectName:$targetName exit=$exitCode hash=$inputHash)';
}
