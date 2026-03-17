import 'package:fx_cache/fx_cache.dart';
import 'package:test/test.dart';

void main() {
  group('CacheEntry', () {
    test('constructs with required fields', () {
      final entry = CacheEntry(
        projectName: 'my_package',
        targetName: 'test',
        exitCode: 0,
        stdout: 'All tests passed.',
        stderr: '',
        duration: const Duration(seconds: 5),
        inputHash: 'abc123',
      );

      expect(entry.projectName, equals('my_package'));
      expect(entry.targetName, equals('test'));
      expect(entry.exitCode, equals(0));
      expect(entry.stdout, equals('All tests passed.'));
      expect(entry.stderr, equals(''));
      expect(entry.duration, equals(const Duration(seconds: 5)));
      expect(entry.inputHash, equals('abc123'));
    });

    test('isSuccess returns true when exitCode is 0', () {
      final entry = CacheEntry(
        projectName: 'pkg',
        targetName: 'test',
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
        inputHash: 'hash',
      );
      expect(entry.isSuccess, isTrue);
    });

    test('isSuccess returns false when exitCode is non-zero', () {
      final entry = CacheEntry(
        projectName: 'pkg',
        targetName: 'test',
        exitCode: 1,
        stdout: '',
        stderr: 'Error occurred',
        duration: Duration.zero,
        inputHash: 'hash',
      );
      expect(entry.isSuccess, isFalse);
    });

    test('toJson serializes all fields', () {
      final entry = CacheEntry(
        projectName: 'my_package',
        targetName: 'analyze',
        exitCode: 0,
        stdout: 'No issues found.',
        stderr: '',
        duration: const Duration(milliseconds: 1234),
        inputHash: 'deadbeef',
      );

      final json = entry.toJson();

      expect(json['projectName'], equals('my_package'));
      expect(json['targetName'], equals('analyze'));
      expect(json['exitCode'], equals(0));
      expect(json['stdout'], equals('No issues found.'));
      expect(json['stderr'], equals(''));
      expect(json['durationMs'], equals(1234));
      expect(json['inputHash'], equals('deadbeef'));
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'projectName': 'my_package',
        'targetName': 'analyze',
        'exitCode': 0,
        'stdout': 'No issues found.',
        'stderr': '',
        'durationMs': 1234,
        'inputHash': 'deadbeef',
      };

      final entry = CacheEntry.fromJson(json);

      expect(entry.projectName, equals('my_package'));
      expect(entry.targetName, equals('analyze'));
      expect(entry.exitCode, equals(0));
      expect(entry.stdout, equals('No issues found.'));
      expect(entry.stderr, equals(''));
      expect(entry.duration, equals(const Duration(milliseconds: 1234)));
      expect(entry.inputHash, equals('deadbeef'));
    });

    test('round-trip toJson/fromJson preserves all fields', () {
      final original = CacheEntry(
        projectName: 'pkg',
        targetName: 'build',
        exitCode: 2,
        stdout: 'stdout content',
        stderr: 'stderr content',
        duration: const Duration(minutes: 1, seconds: 30),
        inputHash: 'sha256hash',
      );

      final roundTripped = CacheEntry.fromJson(original.toJson());

      expect(roundTripped.projectName, equals(original.projectName));
      expect(roundTripped.targetName, equals(original.targetName));
      expect(roundTripped.exitCode, equals(original.exitCode));
      expect(roundTripped.stdout, equals(original.stdout));
      expect(roundTripped.stderr, equals(original.stderr));
      expect(roundTripped.duration, equals(original.duration));
      expect(roundTripped.inputHash, equals(original.inputHash));
    });

    test('toString includes project, target, exitCode, and hash', () {
      final entry = CacheEntry(
        projectName: 'my_lib',
        targetName: 'test',
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
        inputHash: 'abc123',
      );
      final str = entry.toString();
      expect(str, contains('my_lib'));
      expect(str, contains('test'));
      expect(str, contains('0'));
      expect(str, contains('abc123'));
    });

    test('toJson durationMs is integer milliseconds', () {
      final entry = CacheEntry(
        projectName: 'pkg',
        targetName: 'build',
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: const Duration(seconds: 3, milliseconds: 500),
        inputHash: 'h',
      );
      expect(entry.toJson()['durationMs'], equals(3500));
    });

    test('fromJson handles zero duration', () {
      final entry = CacheEntry.fromJson({
        'projectName': 'pkg',
        'targetName': 'test',
        'exitCode': 0,
        'stdout': '',
        'stderr': '',
        'durationMs': 0,
        'inputHash': 'h',
      });
      expect(entry.duration, equals(Duration.zero));
    });
  });
}
