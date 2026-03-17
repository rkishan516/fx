import 'generator.dart';

/// A workspace template that generates a complete workspace structure
/// for `fx init --template <name>`.
class WorkspaceTemplate {
  final String name;
  final String description;
  final Future<List<GeneratedFile>> Function(String workspaceName) _generator;

  WorkspaceTemplate({
    required this.name,
    required this.description,
    required Future<List<GeneratedFile>> Function(String workspaceName)
    generator,
  }) : _generator = generator;

  Future<List<GeneratedFile>> generate(String workspaceName) =>
      _generator(workspaceName);

  static final Map<String, WorkspaceTemplate> _builtIns = {
    'default': _defaultTemplate(),
    'fullstack': _fullstackTemplate(),
    'plugin': _pluginTemplate(),
    'library': _libraryTemplate(),
  };

  static WorkspaceTemplate? builtIn(String name) => _builtIns[name];

  static List<String> get availableTemplates => _builtIns.keys.toList();

  // ---------- Built-in templates ----------

  static WorkspaceTemplate _defaultTemplate() => WorkspaceTemplate(
    name: 'default',
    description: 'Standard workspace with packages/ and apps/ directories',
    generator: (name) async => [
      GeneratedFile(
        relativePath: 'pubspec.yaml',
        content: _rootPubspec(name, ['packages/*', 'apps/*']),
      ),
      GeneratedFile(relativePath: '.gitignore', content: _gitignore),
      GeneratedFile(
        relativePath: 'analysis_options.yaml',
        content: _analysisOptions,
      ),
    ],
  );

  static WorkspaceTemplate _fullstackTemplate() => WorkspaceTemplate(
    name: 'fullstack',
    description:
        'Fullstack workspace with frontend, backend, and shared packages',
    generator: (name) async => [
      GeneratedFile(
        relativePath: 'pubspec.yaml',
        content: _rootPubspec(name, [
          'packages/frontend',
          'packages/backend',
          'packages/shared',
        ]),
      ),
      GeneratedFile(relativePath: '.gitignore', content: _gitignore),
      GeneratedFile(
        relativePath: 'analysis_options.yaml',
        content: _analysisOptions,
      ),
      ..._packageFiles(
        'frontend',
        'Frontend application package.',
        deps: {'shared': '../shared'},
      ),
      ..._packageFiles(
        'backend',
        'Backend server package.',
        deps: {'shared': '../shared'},
      ),
      ..._packageFiles('shared', 'Shared models and utilities.'),
    ],
  );

  static WorkspaceTemplate _pluginTemplate() => WorkspaceTemplate(
    name: 'plugin',
    description: 'Plugin workspace with plugin and example packages',
    generator: (name) async => [
      GeneratedFile(
        relativePath: 'pubspec.yaml',
        content: _rootPubspec(name, [
          'packages/$name',
          'packages/${name}_example',
        ]),
      ),
      GeneratedFile(relativePath: '.gitignore', content: _gitignore),
      GeneratedFile(
        relativePath: 'analysis_options.yaml',
        content: _analysisOptions,
      ),
      ..._packageFiles(name, 'The $name plugin.'),
      ..._packageFiles(
        '${name}_example',
        'Example app for $name.',
        deps: {name: '../$name'},
      ),
    ],
  );

  static WorkspaceTemplate _libraryTemplate() => WorkspaceTemplate(
    name: 'library',
    description: 'Library workspace with core and umbrella packages',
    generator: (name) async => [
      GeneratedFile(
        relativePath: 'pubspec.yaml',
        content: _rootPubspec(name, [
          'packages/${name}_core',
          'packages/$name',
        ]),
      ),
      GeneratedFile(relativePath: '.gitignore', content: _gitignore),
      GeneratedFile(
        relativePath: 'analysis_options.yaml',
        content: _analysisOptions,
      ),
      ..._packageFiles('${name}_core', 'Core implementation of $name.'),
      ..._packageFiles(
        name,
        'Umbrella package for $name.',
        deps: {'${name}_core': '../${name}_core'},
      ),
    ],
  );

  // ---------- Helpers ----------

  static String _rootPubspec(String name, List<String> members) {
    final ws = members.map((m) => '  - $m').join('\n');
    final pkgs = members.map((m) => '    - $m').join('\n');
    return '''
name: ${name}_workspace
description: "$name — fx managed monorepo workspace."
publish_to: none

environment:
  sdk: ^3.11.1

workspace:
$ws

fx:
  packages:
$pkgs
  targets:
    test:
      executor: dart test
    analyze:
      executor: dart analyze
    format:
      executor: dart format .
  cache:
    enabled: true
    directory: .fx_cache
''';
  }

  static List<GeneratedFile> _packageFiles(
    String pkgName,
    String description, {
    Map<String, String> deps = const {},
  }) {
    final depLines = StringBuffer();
    if (deps.isNotEmpty) {
      depLines.writeln('dependencies:');
      for (final entry in deps.entries) {
        depLines.writeln('  ${entry.key}:');
        depLines.writeln('    path: ${entry.value}');
      }
    }

    return [
      GeneratedFile(
        relativePath: 'packages/$pkgName/pubspec.yaml',
        content:
            '''
name: $pkgName
description: $description
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.11.1

${depLines}dev_dependencies:
  lints: ^6.1.0
  test: ^1.24.0
''',
      ),
      GeneratedFile(
        relativePath: 'packages/$pkgName/lib/$pkgName.dart',
        content:
            '''
/// $description
library $pkgName;
''',
      ),
      GeneratedFile(
        relativePath: 'packages/$pkgName/lib/src/.gitkeep',
        content: '',
      ),
    ];
  }

  static const _gitignore = '''
.dart_tool/
.fx_cache/
build/
''';

  static const _analysisOptions = '''
include: package:lints/recommended.yaml
''';
}
