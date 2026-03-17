import 'package:fx_generator/fx_generator.dart';
import 'package:test/test.dart';

void main() {
  group('GeneratorRegistry', () {
    test('contains built-in dart_package generator', () {
      final registry = GeneratorRegistry.withBuiltIns();
      expect(registry.get('dart_package'), isNotNull);
    });

    test('contains built-in flutter_package generator', () {
      final registry = GeneratorRegistry.withBuiltIns();
      expect(registry.get('flutter_package'), isNotNull);
    });

    test('contains built-in flutter_app generator', () {
      final registry = GeneratorRegistry.withBuiltIns();
      expect(registry.get('flutter_app'), isNotNull);
    });

    test('contains built-in dart_cli generator', () {
      final registry = GeneratorRegistry.withBuiltIns();
      expect(registry.get('dart_cli'), isNotNull);
    });

    test('get returns null for unknown generator', () {
      final registry = GeneratorRegistry.withBuiltIns();
      expect(registry.get('nonexistent'), isNull);
    });

    test('all returns all registered generators', () {
      final registry = GeneratorRegistry.withBuiltIns();
      final all = registry.all;
      expect(all.length, greaterThanOrEqualTo(4));
    });

    test('register adds a custom generator', () {
      final registry = GeneratorRegistry.withBuiltIns();
      final custom = _MockGenerator('my_generator');
      registry.register(custom);

      expect(registry.get('my_generator'), equals(custom));
    });

    test('all includes custom registered generators', () {
      final registry = GeneratorRegistry.withBuiltIns();
      registry.register(_MockGenerator('custom'));

      final names = registry.all.map((g) => g.name).toList();
      expect(names, contains('custom'));
    });

    test('register overwrites generator with same name', () {
      final registry = GeneratorRegistry.withBuiltIns();
      final v1 = _MockGenerator('dart_package');
      final v2 = _MockGenerator('dart_package');

      registry.register(v1);
      registry.register(v2);

      expect(registry.get('dart_package'), equals(v2));
    });
  });
}

class _MockGenerator extends Generator {
  _MockGenerator(this._name);

  final String _name;

  @override
  String get name => _name;

  @override
  String get description => 'Mock generator';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async => [];
}
