import 'dart:async';

import 'package:fx_generator/fx_generator.dart';
import 'package:test/test.dart';

void main() {
  group('PromptRunner', () {
    late StringBuffer output;

    setUp(() {
      output = StringBuffer();
    });

    PromptRunner makeRunner(List<String> answers) {
      final controller = StreamController<String>();
      for (final answer in answers) {
        controller.add(answer);
      }
      controller.close();
      return PromptRunner(output: output, input: controller.stream);
    }

    test('prompts for missing text parameter', () async {
      final runner = makeRunner(['my_value']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'description',
            message: 'Project description',
          ),
        ],
        providedVariables: {},
      );

      expect(result['description'], 'my_value');
      expect(output.toString(), contains('Project description'));
    });

    test('skips parameter already provided', () async {
      final runner = makeRunner([]);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'description',
            message: 'Project description',
          ),
        ],
        providedVariables: {'description': 'existing'},
      );

      expect(result['description'], 'existing');
    });

    test('uses default value when user enters empty string', () async {
      final runner = makeRunner(['']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'author',
            message: 'Author name',
            defaultValue: 'Anonymous',
          ),
        ],
        providedVariables: {},
      );

      expect(result['author'], 'Anonymous');
      expect(output.toString(), contains('[Anonymous]'));
    });

    test('confirm prompt returns true for y', () async {
      final runner = makeRunner(['y']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'add_tests',
            message: 'Add test scaffolding?',
            type: PromptType.confirm,
            defaultValue: 'false',
          ),
        ],
        providedVariables: {},
      );

      expect(result['add_tests'], 'true');
    });

    test('confirm prompt returns false for n', () async {
      final runner = makeRunner(['n']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'add_tests',
            message: 'Add test scaffolding?',
            type: PromptType.confirm,
          ),
        ],
        providedVariables: {},
      );

      expect(result['add_tests'], 'false');
    });

    test('confirm prompt uses default on empty input', () async {
      final runner = makeRunner(['']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'add_tests',
            message: 'Add test scaffolding?',
            type: PromptType.confirm,
            defaultValue: 'true',
          ),
        ],
        providedVariables: {},
      );

      expect(result['add_tests'], 'true');
    });

    test('select prompt returns chosen option', () async {
      final runner = makeRunner(['2']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'style',
            message: 'Select code style:',
            type: PromptType.select,
            choices: ['minimal', 'standard', 'full'],
          ),
        ],
        providedVariables: {},
      );

      expect(result['style'], 'standard');
    });

    test('select prompt uses default on invalid input', () async {
      final runner = makeRunner(['99']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(
            name: 'style',
            message: 'Select code style:',
            type: PromptType.select,
            choices: ['minimal', 'standard', 'full'],
            defaultValue: 'standard',
          ),
        ],
        providedVariables: {},
      );

      expect(result['style'], 'standard');
    });

    test('multiple prompts in sequence', () async {
      final runner = makeRunner(['My Lib', 'y', '1']);
      final result = await runner.run(
        prompts: [
          const GeneratorPrompt(name: 'description', message: 'Description'),
          const GeneratorPrompt(
            name: 'add_tests',
            message: 'Add tests?',
            type: PromptType.confirm,
          ),
          const GeneratorPrompt(
            name: 'template',
            message: 'Template:',
            type: PromptType.select,
            choices: ['basic', 'full'],
          ),
        ],
        providedVariables: {},
      );

      expect(result['description'], 'My Lib');
      expect(result['add_tests'], 'true');
      expect(result['template'], 'basic');
    });
  });

  group('PromptRunner.validateRequired', () {
    test('returns missing required parameters', () {
      final missing = PromptRunner.validateRequired(
        prompts: [
          const GeneratorPrompt(name: 'name', message: 'Name', required: true),
          const GeneratorPrompt(name: 'desc', message: 'Desc', required: true),
          const GeneratorPrompt(
            name: 'opt',
            message: 'Optional',
            required: false,
          ),
        ],
        variables: {'name': 'test'},
      );

      expect(missing, ['desc']);
    });

    test('returns empty when all required params present', () {
      final missing = PromptRunner.validateRequired(
        prompts: [
          const GeneratorPrompt(name: 'name', message: 'Name', required: true),
        ],
        variables: {'name': 'test'},
      );

      expect(missing, isEmpty);
    });

    test('returns empty for no prompts', () {
      final missing = PromptRunner.validateRequired(prompts: [], variables: {});

      expect(missing, isEmpty);
    });
  });

  group('Generator.prompts', () {
    test('default prompts is empty list', () {
      final gen = _NoPromptsGenerator();
      expect(gen.prompts, isEmpty);
    });

    test('custom generator can declare prompts', () {
      final gen = _WithPromptsGenerator();
      expect(gen.prompts, hasLength(2));
      expect(gen.prompts.first.name, 'author');
      expect(gen.prompts.last.type, PromptType.confirm);
    });
  });
}

class _NoPromptsGenerator extends Generator {
  @override
  String get name => 'no-prompts';
  @override
  String get description => 'Generator without prompts';
  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async => [];
}

class _WithPromptsGenerator extends Generator {
  @override
  String get name => 'with-prompts';
  @override
  String get description => 'Generator with prompts';

  @override
  List<GeneratorPrompt> get prompts => const [
    GeneratorPrompt(name: 'author', message: 'Author name'),
    GeneratorPrompt(
      name: 'add_tests',
      message: 'Add test scaffolding?',
      type: PromptType.confirm,
      defaultValue: 'true',
    ),
  ];

  @override
  Future<List<GeneratedFile>> generate(GeneratorContext context) async => [];
}
