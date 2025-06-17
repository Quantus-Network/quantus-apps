import 'dart:io';
import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class WalletCommand {
  WalletCommand();

  ArgParser get argParser {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Print this command usage information.',
        negatable: false,
      );

    // Add subcommands
    parser.addCommand('create')
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Print this command usage information.',
        negatable: false,
      );

    parser.addCommand('import')
      ..addOption(
        'mnemonic',
        abbr: 'm',
        help: 'Mnemonic phrase to import',
        mandatory: true,
      )
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Print this command usage information.',
        negatable: false,
      );

    parser.addCommand('list')
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Print this command usage information.',
        negatable: false,
      );

    parser.addCommand('balance')
      ..addOption(
        'address',
        abbr: 'a',
        help: 'Account address to check balance for',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Print this command usage information.',
        negatable: false,
      );

    return parser;
  }

  Future<void> run(ArgResults command) async {
    final logger = Logger();

    if (command['help'] as bool) {
      _printUsage();
      return;
    }

    final subcommand = command.command;
    if (subcommand == null) {
      logger.err('No subcommand specified. Use --help for usage information.');
      exit(1);
    }

    switch (subcommand.name) {
      case 'create':
        await _createWallet(logger);
        break;
      case 'import':
        await _importWallet(logger, subcommand);
        break;
      case 'list':
        await _listWallets(logger);
        break;
      case 'balance':
        await _checkBalance(logger, subcommand);
        break;
      default:
        logger.err('Unknown subcommand: ${subcommand.name}');
        exit(1);
    }
  }

  Future<void> _createWallet(Logger logger) async {
    try {
      final substrateService = SubstrateService();
      await substrateService.initialize();

      final mnemonic = await substrateService.generateMnemonic();
      final walletInfo = await substrateService.generateWalletFromSeed(mnemonic);

      logger.info('✅ New wallet created successfully!');
      logger.info('Address: ${walletInfo.accountId}');
      logger.warn('⚠️  IMPORTANT: Save your mnemonic phrase securely:');
      logger.info('Mnemonic: $mnemonic');
      logger.warn('⚠️  Anyone with this mnemonic can access your funds!');
    } catch (e) {
      logger.err('Failed to create wallet: $e');
      exit(1);
    }
  }

  Future<void> _importWallet(Logger logger, ArgResults command) async {
    try {
      final mnemonic = command['mnemonic'] as String;
      final substrateService = SubstrateService();
      await substrateService.initialize();

      final walletInfo = await substrateService.generateWalletFromSeed(mnemonic);

      logger.info('✅ Wallet imported successfully!');
      logger.info('Address: ${walletInfo.accountId}');
    } catch (e) {
      logger.err('Failed to import wallet: $e');
      exit(1);
    }
  }

  Future<void> _listWallets(Logger logger) async {
    try {
      // This would typically read from local storage/config
      logger.info('📋 Wallet management features coming soon...');
      logger.info('For now, use individual wallet operations.');
    } catch (e) {
      logger.err('Failed to list wallets: $e');
      exit(1);
    }
  }

  Future<void> _checkBalance(Logger logger, ArgResults command) async {
    try {
      final address = command['address'] as String?;
      if (address == null) {
        logger.err('Address is required. Use --address or -a to specify.');
        exit(1);
      }

      final substrateService = SubstrateService();
      await substrateService.initialize();

      final balance = await substrateService.queryBalance(address);
      final formattedBalance = NumberFormattingService().formatBalance(balance);

      logger.info('💰 Balance for $address:');
      logger.info('$formattedBalance QUAN');
    } catch (e) {
      logger.err('Failed to check balance: $e');
      exit(1);
    }
  }

  void _printUsage() {
    final logger = Logger();
    logger.info('''
Wallet management commands

Usage: resonance wallet <subcommand> [arguments]

Available subcommands:
  create                   Create a new wallet
  import --mnemonic <phrase>  Import wallet from mnemonic
  list                     List available wallets
  balance --address <addr> Check balance for an address

Examples:
  resonance wallet create
  resonance wallet import --mnemonic "word1 word2 ... word12"
  resonance wallet balance --address 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY
''');
  }
}
