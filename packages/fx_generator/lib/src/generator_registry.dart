import 'generator.dart';
import 'generators/dart_cli_generator.dart';
import 'generators/dart_package_generator.dart';
import 'generators/flutter_app_generator.dart';
import 'generators/flutter_package_generator.dart';
import 'generators/workspace_generator.dart';

/// Registry of all available generators.
///
/// Built-in generators are registered via [withBuiltIns]. Additional
/// generators (from plugins) can be added via [register].
class GeneratorRegistry {
  final Map<String, Generator> _generators = {};

  GeneratorRegistry();

  /// Creates a registry pre-populated with all built-in generators.
  factory GeneratorRegistry.withBuiltIns() {
    return GeneratorRegistry()
      ..register(DartPackageGenerator())
      ..register(FlutterPackageGenerator())
      ..register(FlutterAppGenerator())
      ..register(DartCliGenerator())
      ..register(AddDependencyGenerator())
      ..register(RenamePackageGenerator())
      ..register(MovePackageGenerator());
  }

  /// Adds [generator] to the registry. Overwrites any existing generator
  /// with the same [Generator.name].
  void register(Generator generator) {
    _generators[generator.name] = generator;
  }

  /// Returns the generator with [name], or null if not found.
  Generator? get(String name) => _generators[name];

  /// Returns all registered generators.
  List<Generator> get all => List.unmodifiable(_generators.values);
}
