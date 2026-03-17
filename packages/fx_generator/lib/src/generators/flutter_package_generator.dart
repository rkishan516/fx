import '../generator.dart';
import '../template_engine.dart';

/// Generates a new Flutter package within the workspace.
class FlutterPackageGenerator extends Generator {
  static const _engine = TemplateEngine();

  @override
  String get name => 'flutter_package';

  @override
  String get description => 'Generate a new Flutter package.';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async {
    final vars = {
      'name': context.projectName,
      'description':
          context.variables['description'] ?? 'A new Flutter package.',
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
            relativePath: 'lib/{{name}}.dart',
            content: _engine.render(_barrel, vars),
          ),
          GeneratedFile(relativePath: 'lib/src/.gitkeep', content: ''),
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
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^6.1.0
''';

const _analysisOptions = '''
include: package:lints/recommended.yaml
''';

const _barrel = '''
/// {{description}}
library {{name}};
''';

const _testFile = '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder', (WidgetTester tester) async {
    expect(true, isTrue);
  });
}
''';
