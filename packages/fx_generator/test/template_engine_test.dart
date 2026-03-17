import 'package:fx_generator/fx_generator.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateEngine', () {
    test('renders template with no variables unchanged', () {
      const engine = TemplateEngine();
      final result = engine.render('Hello, World!', {});
      expect(result, equals('Hello, World!'));
    });

    test('substitutes a single variable', () {
      const engine = TemplateEngine();
      final result = engine.render('Hello, {{name}}!', {'name': 'fx'});
      expect(result, equals('Hello, fx!'));
    });

    test('substitutes multiple variables', () {
      const engine = TemplateEngine();
      final result = engine.render('package: {{name}}, desc: {{description}}', {
        'name': 'my_pkg',
        'description': 'A great package',
      });
      expect(result, equals('package: my_pkg, desc: A great package'));
    });

    test('substitutes the same variable multiple times', () {
      const engine = TemplateEngine();
      final result = engine.render('{{name}} / {{name}}', {'name': 'foo'});
      expect(result, equals('foo / foo'));
    });

    test('leaves unknown variables as-is', () {
      const engine = TemplateEngine();
      final result = engine.render('Hello, {{unknown}}!', {});
      expect(result, equals('Hello, {{unknown}}!'));
    });

    test('handles empty template', () {
      const engine = TemplateEngine();
      expect(engine.render('', {'name': 'x'}), equals(''));
    });

    test('renders multiline templates', () {
      const engine = TemplateEngine();
      const template = 'name: {{name}}\nversion: {{version}}\n';
      final result = engine.render(template, {
        'name': 'my_package',
        'version': '0.1.0',
      });
      expect(result, equals('name: my_package\nversion: 0.1.0\n'));
    });

    test('handles variable with underscores and numbers', () {
      const engine = TemplateEngine();
      final result = engine.render('{{my_var_1}}', {'my_var_1': 'value'});
      expect(result, equals('value'));
    });

    test('handles adjacent template expressions', () {
      const engine = TemplateEngine();
      final result = engine.render('{{a}}{{b}}', {'a': 'hello', 'b': 'world'});
      expect(result, equals('helloworld'));
    });

    test('handles template with only a variable', () {
      const engine = TemplateEngine();
      final result = engine.render('{{name}}', {'name': 'value'});
      expect(result, equals('value'));
    });

    test('preserves whitespace around variables', () {
      const engine = TemplateEngine();
      final result = engine.render('  {{name}}  ', {'name': 'x'});
      expect(result, equals('  x  '));
    });

    test('handles empty variable value', () {
      const engine = TemplateEngine();
      final result = engine.render('prefix-{{name}}-suffix', {'name': ''});
      expect(result, equals('prefix--suffix'));
    });

    test('handles variable value containing special characters', () {
      const engine = TemplateEngine();
      final result = engine.render('{{desc}}', {
        'desc': 'A package with special chars: <>&"',
      });
      expect(result, equals('A package with special chars: <>&"'));
    });
  });
}
