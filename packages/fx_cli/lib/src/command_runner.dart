import 'dart:io';

import 'package:cli_completion/cli_completion.dart';
import 'package:fx_core/fx_core.dart';
import 'package:fx_runner/fx_runner.dart';

import 'commands/add_command.dart';
import 'commands/ci_info_command.dart';
import 'commands/affected_command.dart';
import 'commands/analyze_command.dart';
import 'commands/bootstrap_command.dart';
import 'commands/cache_command.dart';
import 'commands/check_commands.dart';
import 'commands/configure_ai_agents_command.dart';
import 'commands/daemon_command.dart';
import 'commands/exec_command.dart';
import 'commands/format_command.dart';
import 'commands/generate_command.dart';
import 'commands/graph_command.dart';
import 'commands/import_command.dart';
import 'commands/plugin_command.dart';
import 'commands/init_command.dart';
import 'commands/lint_command.dart';
import 'commands/mcp_command.dart';
import 'commands/list_command.dart';
import 'commands/migrate_command.dart';
import 'commands/release_command.dart';
import 'commands/repair_command.dart';
import 'commands/report_command.dart';
import 'commands/reset_command.dart';
import 'commands/run_command.dart';
import 'commands/run_many_command.dart';
import 'commands/show_command.dart';
import 'commands/sync_command.dart';
import 'commands/watch_command.dart';
import 'output/output_formatter.dart';

/// The root command runner for the `fx` CLI.
///
/// Extends [CompletionCommandRunner] to enable shell tab completion via
/// `fx completion install`.
class FxCommandRunner extends CompletionCommandRunner<void> {
  final OutputFormatter formatter;

  FxCommandRunner({
    StringSink? outputSink,
    ProcessRunner? processRunner,
    String? cacheDir,
    MigrationRegistry? migrationRegistry,
  }) : formatter = OutputFormatter(outputSink ?? stdout),
       super('fx', 'A Dart/Flutter monorepo management tool.') {
    final effectiveRunner = processRunner ?? const SystemProcessRunner();

    addCommand(
      AddCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(InitCommand());
    addCommand(ListCommand(formatter: formatter));
    addCommand(GraphCommand(formatter: formatter));
    addCommand(
      RunCommand(
        formatter: formatter,
        processRunner: effectiveRunner,
        cacheDir: cacheDir,
      ),
    );
    addCommand(
      RunManyCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(
      AffectedCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(CacheCommand(formatter: formatter, cacheDir: cacheDir));
    addCommand(GenerateCommand(formatter: formatter));
    addCommand(ConfigureAiAgentsCommand(formatter: formatter));
    addCommand(
      BootstrapCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(
      FormatCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(
      AnalyzeCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(
      ImportCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(PluginCommand(formatter: formatter));
    addCommand(RepairCommand(formatter: formatter));
    addCommand(ReportCommand(formatter: formatter));
    addCommand(ResetCommand(formatter: formatter));
    addCommand(ShowCommand(formatter: formatter));
    addCommand(
      SyncCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(LintCommand(formatter: formatter));
    addCommand(
      WatchCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(
      FormatCheckCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(SyncCheckCommand(formatter: formatter));
    addCommand(McpCommand(formatter: formatter));
    addCommand(CiInfoCommand(formatter: formatter));
    addCommand(
      MigrateCommand(
        formatter: formatter,
        migrationRegistry: migrationRegistry,
      ),
    );
    addCommand(DaemonCommand(formatter: formatter));
    addCommand(
      ExecCommand(formatter: formatter, processRunner: effectiveRunner),
    );
    addCommand(
      ReleaseCommand(formatter: formatter, processRunner: effectiveRunner),
    );
  }
}
