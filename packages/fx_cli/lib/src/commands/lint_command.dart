import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';

import '../output/output_formatter.dart';
import 'run_command.dart';

/// Converts config-level ConformanceRuleConfig to graph-level ConformanceRule.
ConformanceRule _toGraphRule(ConformanceRuleConfig c) =>
    ConformanceRule(id: c.id, type: c.type, options: c.options);

/// `fx lint` — Enforce module boundaries and project constraints.
class LintCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'lint';

  @override
  String get description =>
      'Enforce module boundaries and project constraints.\n\n'
      'Checks that project dependencies respect the configured module boundary rules.';

  LintCommand({required this.formatter}) {
    argParser.addOption(
      'workspace',
      help: 'Path to workspace root (for testing).',
      hide: true,
    );
  }

  @override
  Future<void> run() async {
    final workspacePath = argResults!['workspace'] as String?;
    final workspace = await WorkspaceLoader.load(
      workspacePath ?? _findWorkspaceRoot(),
    );

    // Check module boundaries
    final violations = ModuleBoundaryEnforcer.enforce(
      projects: workspace.projects,
      rules: workspace.config.moduleBoundaries,
    );

    // Check for circular dependencies
    final graph = ProjectGraph.build(workspace.projects);
    final cycles = CycleDetector.findCycles(graph);

    var hasErrors = false;

    if (cycles.isNotEmpty) {
      hasErrors = true;
      formatter.writeln('Circular dependencies detected:');
      for (final cycle in cycles) {
        formatter.writeln('  ${cycle.join(' -> ')} -> ${cycle.first}');
      }
      formatter.writeln('');
    }

    if (violations.isNotEmpty) {
      hasErrors = true;
      formatter.writeln('Module boundary violations:');
      for (final v in violations) {
        formatter.writeln('  ${v.sourceProject} -> ${v.targetProject}');
        formatter.writeln('    ${v.rule}');
      }
      formatter.writeln('');
    }

    // Check conformance rules
    if (workspace.config.conformanceRules.isNotEmpty) {
      final conformanceViolations = ConformanceEnforcer.enforce(
        projects: workspace.projects,
        rules: workspace.config.conformanceRules.map(_toGraphRule).toList(),
        config: workspace.config,
      );
      if (conformanceViolations.isNotEmpty) {
        hasErrors = true;
        formatter.writeln('Conformance rule violations:');
        for (final v in conformanceViolations) {
          formatter.writeln('  ${v.projectName}: [${v.ruleId}] ${v.message}');
        }
        formatter.writeln('');
      }
    }

    if (hasErrors) {
      formatter.writeln('Lint failed with errors.');
      throw const ProcessExit(1);
    } else {
      formatter.writeln('All lint checks passed.');
    }
  }

  String _findWorkspaceRoot() {
    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }
    return root;
  }
}
