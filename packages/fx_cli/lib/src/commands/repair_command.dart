import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fx_core/fx_core.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../output/output_formatter.dart';

/// `fx repair` — Scan and fix workspace configuration issues.
class RepairCommand extends Command<void> {
  final OutputFormatter formatter;

  @override
  String get name => 'repair';

  @override
  String get description =>
      'Scan for workspace configuration issues and fix them.';

  RepairCommand({required this.formatter});

  @override
  Future<void> run() async {
    final root = FileUtils.findWorkspaceRoot(Directory.current.path);
    if (root == null) {
      throw UsageException(
        'Not inside an fx workspace. Run `fx init` first.',
        usage,
      );
    }

    var fixed = 0;
    var issues = 0;

    // Check 1: All workspace members have pubspec.yaml
    final pubspecFile = File(p.join(root, 'pubspec.yaml'));
    final content = pubspecFile.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;
    final workspace = yaml['workspace'];
    if (workspace is YamlList) {
      for (final member in workspace) {
        final memberStr = member.toString();
        if (memberStr.contains('*')) continue; // Skip globs
        final memberPubspec = File(p.join(root, memberStr, 'pubspec.yaml'));
        if (!memberPubspec.existsSync()) {
          formatter.writeln(
            '  WARN: Workspace member "$memberStr" has no pubspec.yaml',
          );
          issues++;
        }
      }
    }

    // Check 2: Sub-packages have resolution: workspace
    final config = _loadConfig(root, yaml);
    final pubspecs = FileUtils.findPubspecs(root, config.packages);
    for (final pubspecPath in pubspecs) {
      final pkgContent = File(pubspecPath).readAsStringSync();
      final pkgYaml = loadYaml(pkgContent) as YamlMap;
      final resolution = pkgYaml['resolution']?.toString();

      if (resolution != 'workspace') {
        formatter.writeln(
          '  FIX: Adding resolution: workspace to ${p.relative(pubspecPath, from: root)}',
        );
        final editor = YamlEditor(pkgContent);
        editor.update(['resolution'], 'workspace');
        File(pubspecPath).writeAsStringSync(editor.toString());
        fixed++;
      }
    }

    // Check 3: Sub-packages have publish_to: none
    for (final pubspecPath in pubspecs) {
      final pkgContent = File(pubspecPath).readAsStringSync();
      final pkgYaml = loadYaml(pkgContent) as YamlMap;
      final publishTo = pkgYaml['publish_to'];

      if (publishTo == null) {
        formatter.writeln(
          '  FIX: Adding publish_to: none to ${p.relative(pubspecPath, from: root)}',
        );
        final editor = YamlEditor(pkgContent);
        editor.update(['publish_to'], 'none');
        File(pubspecPath).writeAsStringSync(editor.toString());
        fixed++;
      }
    }

    // Check 4: .gitignore exists and includes .fx_cache
    final gitignore = File(p.join(root, '.gitignore'));
    if (gitignore.existsSync()) {
      final gitContent = gitignore.readAsStringSync();
      if (!gitContent.contains('.fx_cache')) {
        formatter.writeln('  FIX: Adding .fx_cache/ to .gitignore');
        gitignore.writeAsStringSync('$gitContent\n.fx_cache/\n');
        fixed++;
      }
    }

    // Check 5: analysis_options.yaml exists
    final analysisOptions = File(p.join(root, 'analysis_options.yaml'));
    if (!analysisOptions.existsSync()) {
      formatter.writeln('  FIX: Creating analysis_options.yaml');
      analysisOptions.writeAsStringSync(
        'include: package:lints/recommended.yaml\n',
      );
      fixed++;
    }

    if (fixed == 0 && issues == 0) {
      formatter.writeln('Workspace is healthy. No issues found.');
    } else {
      formatter.writeln('');
      if (fixed > 0) formatter.writeln('Fixed $fixed issue(s).');
      if (issues > 0) {
        formatter.writeln('$issues warning(s) require manual attention.');
      }
    }
  }

  FxConfig _loadConfig(String rootPath, YamlMap yaml) {
    final fxSection = yaml['fx'];
    if (fxSection is YamlMap) return FxConfig.fromYaml(fxSection);
    return FxConfig.defaults();
  }
}
