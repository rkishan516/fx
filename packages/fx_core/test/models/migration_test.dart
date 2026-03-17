import 'package:fx_core/fx_core.dart';
import 'package:test/test.dart';

void main() {
  group('MigrationChange', () {
    test('serializes and deserializes correctly', () {
      final change = MigrationChange(
        type: MigrationChangeType.modify,
        filePath: 'pubspec.yaml',
        description: 'Update sdk constraint',
        before: 'sdk: ^2.0.0',
        after: 'sdk: ^3.0.0',
      );

      final json = change.toJson();
      final restored = MigrationChange.fromJson(json);

      expect(restored.type, MigrationChangeType.modify);
      expect(restored.filePath, 'pubspec.yaml');
      expect(restored.description, 'Update sdk constraint');
      expect(restored.before, 'sdk: ^2.0.0');
      expect(restored.after, 'sdk: ^3.0.0');
    });

    test('toJson omits null before/after fields', () {
      final change = MigrationChange(
        type: MigrationChangeType.create,
        filePath: 'new_file.dart',
        description: 'Create new file',
      );

      final json = change.toJson();
      expect(json.containsKey('before'), isFalse);
      expect(json.containsKey('after'), isFalse);
    });

    test('fromJson handles missing before/after', () {
      final json = {
        'type': 'delete',
        'filePath': 'old_file.dart',
        'description': 'Remove unused file',
      };

      final change = MigrationChange.fromJson(json);
      expect(change.type, MigrationChangeType.delete);
      expect(change.before, isNull);
      expect(change.after, isNull);
    });
  });

  group('MigrationRegistry', () {
    test('registers and finds migrations for a version range', () {
      final registry = MigrationRegistry();
      final migration = _MockMigration(from: '1.0.0', to: '2.0.0');
      registry.register(migration);

      final found = registry.findMigrations(
        pluginName: 'test-plugin',
        currentVersion: '1.0.0',
        targetVersion: '2.0.0',
      );
      expect(found, hasLength(1));
      expect(found.first.fromVersion, '1.0.0');
    });

    test('returns empty when no migrations match', () {
      final registry = MigrationRegistry();
      registry.register(_MockMigration(from: '1.0.0', to: '2.0.0'));

      final found = registry.findMigrations(
        pluginName: 'test-plugin',
        currentVersion: '3.0.0', // already newer
        targetVersion: '4.0.0',
      );
      expect(found, isEmpty);
    });

    test('returns empty when registry is empty', () {
      final registry = MigrationRegistry();
      final found = registry.findMigrations(
        pluginName: 'test-plugin',
        currentVersion: '1.0.0',
        targetVersion: '2.0.0',
      );
      expect(found, isEmpty);
    });

    test('multiple migrations are ordered by fromVersion', () {
      final registry = MigrationRegistry();
      registry.register(_MockMigration(from: '2.0.0', to: '3.0.0'));
      registry.register(_MockMigration(from: '1.0.0', to: '2.0.0'));

      final found = registry.findMigrations(
        pluginName: 'test-plugin',
        currentVersion: '1.0.0',
        targetVersion: '3.0.0',
      );
      expect(found, hasLength(2));
      expect(found[0].fromVersion, '1.0.0');
      expect(found[1].fromVersion, '2.0.0');
    });
  });

  group('MigrationGenerator', () {
    test('prepare() returns list of changes without applying them', () async {
      final migration = _MockMigration(from: '1.0.0', to: '2.0.0');
      final changes = await migration.prepare('/workspace');
      expect(changes, hasLength(1));
      expect(changes.first.description, contains('test change'));
      // Verify nothing was actually modified (file doesn't exist)
      expect(migration.executeCallCount, 0);
    });

    test('execute() applies changes', () async {
      final migration = _MockMigration(from: '1.0.0', to: '2.0.0');
      final changes = await migration.prepare('/workspace');
      await migration.execute('/workspace', changes);
      expect(migration.executeCallCount, 1);
    });
  });
}

class _MockMigration extends MigrationGenerator {
  final String _from;
  final String _to;
  int executeCallCount = 0;

  _MockMigration({required String from, required String to})
    : _from = from,
      _to = to;

  @override
  String get fromVersion => _from;

  @override
  String get toVersion => _to;

  @override
  String get pluginName => 'test-plugin';

  @override
  Future<List<MigrationChange>> prepare(String workspaceRoot) async {
    return [
      MigrationChange(
        type: MigrationChangeType.modify,
        filePath: 'pubspec.yaml',
        description: 'Apply test change from $_from to $_to',
      ),
    ];
  }

  @override
  Future<void> execute(
    String workspaceRoot,
    List<MigrationChange> changes,
  ) async {
    executeCallCount++;
  }
}
