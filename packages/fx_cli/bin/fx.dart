import 'dart:io';

import 'package:fx_cli/fx_cli.dart';

Future<void> main(List<String> args) async {
  final runner = FxCommandRunner();
  try {
    await runner.run(args);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
