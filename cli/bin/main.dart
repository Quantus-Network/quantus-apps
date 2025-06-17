#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import '../lib/commands/balance_command.dart';
import '../lib/commands/reversible_transfers_command.dart';
import '../lib/commands/recovery_command.dart';
import '../lib/commands/wallet_command.dart';
import '../lib/commands/mining_command.dart';

final logger = Logger();

Future<void> main(List<String> arguments) async {
  logger.info('🚀 Resonance Network CLI');

  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Print this usage information.',
      negatable: false,
    )
    ..addFlag(
      'version',
      abbr: 'v',
      help: 'Print the tool version.',
      negatable: false,
    );

  // Add subcommands
  parser.addCommand('wallet', WalletCommand().argParser);
  parser.addCommand('balance', BalanceCommand().argParser);
  parser.addCommand('transfer', ReversibleTransfersCommand().argParser);
  parser.addCommand('recovery', RecoveryCommand().argParser);
  parser.addCommand('mining', MiningCommand().argParser);

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printUsage(parser);
      return;
    }

    if (results['version'] as bool) {
      logger.info('Resonance CLI version 1.0.0');
      return;
    }

    // Initialize SDK
    await QuantusSdk.init();

    // Handle subcommands
    final command = results.command;
    if (command == null) {
      logger.err('No command specified. Use --help for usage information.');
      exit(1);
    }

    switch (command.name) {
      case 'wallet':
        await WalletCommand().run(command);
        break;
      case 'balance':
        await BalanceCommand().run(command);
        break;
      case 'transfer':
        await ReversibleTransfersCommand().run(command);
        break;
      case 'recovery':
        await RecoveryCommand().run(command);
        break;
      case 'mining':
        await MiningCommand().run(command);
        break;
      default:
        logger.err('Unknown command: ${command.name}');
        exit(1);
    }
  } catch (e) {
    logger.err('Error: $e');
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  logger.info('''
Resonance Network CLI - Command line interface for blockchain operations

Usage: resonance <command> [arguments]

Global options:
${parser.usage}

Available commands:
  wallet     Wallet management (create, import, list)
  balance    Check account balances
  transfer   Reversible transfer operations (theft deterrence)
  recovery   Account recovery operations
  mining     Mining and node operations

Run "resonance <command> --help" for more information about a command.
''');
}
