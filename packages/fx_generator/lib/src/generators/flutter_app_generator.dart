import '../generator.dart';
import '../template_engine.dart';

/// Generates a new Flutter application within the workspace.
class FlutterAppGenerator extends Generator {
  static const _engine = TemplateEngine();

  @override
  String get name => 'flutter_app';

  @override
  String get description => 'Generate a new Flutter application.';

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async {
    final vars = {
      'name': context.projectName,
      'description':
          context.variables['description'] ?? 'A new Flutter application.',
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
            relativePath: 'lib/main.dart',
            content: _engine.render(_mainDart, vars),
          ),
          GeneratedFile(
            relativePath: 'lib/app.dart',
            content: _engine.render(_appDart, vars),
          ),
          GeneratedFile(
            relativePath: 'test/widget_test.dart',
            content: _engine.render(_widgetTest, vars),
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
version: 1.0.0+1
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

const _mainDart = '''
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const App());
}
''';

const _appDart = '''
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '{{name}}',
      home: Scaffold(
        appBar: AppBar(title: const Text('{{name}}')),
        body: const Center(child: Text('Hello, World!')),
      ),
    );
  }
}
''';

const _widgetTest = '''
import 'package:flutter_test/flutter_test.dart';

import 'package:{{name}}/app.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Hello, World!'), findsOneWidget);
  });
}
''';
