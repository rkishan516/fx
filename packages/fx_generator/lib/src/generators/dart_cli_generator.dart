import '../generator.dart';
import '../template_engine.dart';

/// Generates a new Dart CLI tool within the workspace.
class DartCliGenerator extends Generator {
  static const _engine = TemplateEngine();

  @override
  String get name => 'dart_cli';

  @override
  String get description => 'Generate a new Dart CLI tool.';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async {
    final vars = {
      'name': context.projectName,
      'description': context.variables['description'] ?? 'A new Dart CLI tool.',
      ...context.variables,
    };

    return [
          GeneratedFile(
            relativePath: 'pubspec.yaml',
            content: _engine.render(_pubspec, vars),
          ),
          GeneratedFile(
            relativePath: 'analysis_options.yaml',
            content: _analysisOptions,
          ),
          GeneratedFile(
            relativePath: 'bin/main.dart',
            content: _engine.render(_binMain, vars),
          ),
          GeneratedFile(
            relativePath: 'lib/{{name}}.dart',
            content: _engine.render(_barrel, vars),
          ),
          GeneratedFile(
            relativePath: 'test/{{name}}_test.dart',
            content: _engine.render(_testFile, vars),
          ),
        ]
        .map(
          (f) => GeneratedFile(
            relativePath: _engine.render(f.relativePath, vars),
            content: f.content,
            overwrite: f.overwrite,
          ),
        )
        .toList();
  }
}

const _pubspec = '''
name: {{name}}
description: {{description}}
version: 0.1.0
publish_to: none

resolution: workspace

environment:
  sdk: ^3.11.1

dependencies:
  args: ^2.4.2

dev_dependencies:
  lints: ^6.1.0
  test: ^1.24.0

executables:
  {{name}}: main
''';

const _analysisOptions = '''
include: package:lints/recommended.yaml
''';

const _binMain = '''
import 'package:args/args.dart';

void main(List<String> arguments) {
  final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);
  final results = parser.parse(arguments);

  if (results['help'] as bool) {
    print('Usage: {{name}} [options]');
    print(parser.usage);
    return;
  }

  print('Hello from {{name}}!');
}
''';

const _barrel = '''
/// {{description}}
library {{name}};
''';

const _testFile = '''
import 'package:test/test.dart';

void main() {
  group('{{name}}', () {
    test('placeholder', () {
      expect(true, isTrue);
    });
  });
}
''';
