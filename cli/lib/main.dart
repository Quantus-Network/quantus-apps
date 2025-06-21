import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_cli/commands/send_command.dart';
import 'package:resonance_cli/commands/wallet_command.dart';
import 'package:resonance_cli/runner.dart';

final logger = Logger();

void main(List<String> args) async {
  try {
    await SubstrateService().initialize(); // Initialize SubstrateService
    await QuantusSdk.init();

    final exitCode = await ResonanceCliRunner(
      logger: Logger(),
      commands: [
        WalletCommand(logger: Logger()),
        SendCommand(logger: Logger()),
      ],
    ).run(args);

    await _flushThenExit(exitCode);
  } catch (e, stackTrace) {
    logger.err('Fatal error: $e');
    logger.err('Stack trace: $stackTrace');
    await _flushThenExit(1);
  }
}

Future<void> _flushThenExit(int status) {
  return Future.wait<void>([stdout.close(), stderr.close()]).then<void>((_) => exit(status));
}
