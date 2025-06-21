#!/usr/bin/env dart

import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_cli/commands/send_command.dart';
import 'package:resonance_cli/commands/wallet_command.dart';
import 'package:resonance_cli/runner.dart';

final logger = Logger();

Future<void> main(List<String> args) async {
  ServiceLocator().initialize();
  await ServiceLocator().substrateService.initialize();
  await QuantusSdk.init();

  await _flushThenExit(
    await ResonanceCliRunner(
      logger: Logger(),
      commands: [
        WalletCommand(logger: Logger()),
        SendCommand(logger: Logger()),
      ],
    ).run(args),
  );
}

Future<void> _flushThenExit(int status) {
  return Future.wait<void>([stdout.close(), stderr.close()]).then<void>((_) => exit(status));
}
