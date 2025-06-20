import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class WalletCommand extends Command<int> {
  WalletCommand({required this.logger}) {
    addSubcommand(_SetPassphraseCommand(logger: logger));
    addSubcommand(_ClearPassphraseCommand(logger: logger));
    addSubcommand(_ShowAddressCommand(logger: logger));
  }

  @override
  String get description => 'Manage your wallet passphrase and address.';

  @override
  String get name => 'wallet';

  final Logger logger;
}

class _SetPassphraseCommand extends Command<int> {
  _SetPassphraseCommand({required this.logger}) {
    argParser.addOption('mnemonic', abbr: 'm', help: 'The 12 or 24-word mnemonic passphrase to set.', mandatory: true);
  }

  @override
  String get description => 'Set and save your wallet passphrase securely.';

  @override
  String get name => 'set-passphrase';

  final Logger logger;
  final _settingsService = SettingsService();

  @override
  Future<int> run() async {
    final mnemonic = argResults?['mnemonic'] as String;
    logger.info('Attempting to set passphrase with mnemonic: "$mnemonic"');
    await _settingsService.initialize();
    await _settingsService.setMnemonic(mnemonic);
    logger.success('Passphrase has been set successfully.');
    return ExitCode.success.code;
  }
}

class _ClearPassphraseCommand extends Command<int> {
  _ClearPassphraseCommand({required this.logger});

  @override
  String get description => 'Clear your saved wallet passphrase.';

  @override
  String get name => 'clear-passphrase';

  final Logger logger;
  final _settingsService = SettingsService();

  @override
  Future<int> run() async {
    logger.info('Attempting to clear passphrase...');
    await _settingsService.initialize();
    await _settingsService.clearMnemonic();
    logger.success('Passphrase has been cleared.');
    return ExitCode.success.code;
  }
}

class _ShowAddressCommand extends Command<int> {
  _ShowAddressCommand({required this.logger});

  @override
  String get description => 'Show the public address of your saved wallet.';

  @override
  String get name => 'show-address';

  final Logger logger;
  final _settingsService = SettingsService();
  final _substrateService = SubstrateService();

  @override
  Future<int> run() async {
    logger.info('Attempting to show address...');
    await _settingsService.initialize();
    await _substrateService.initialize();
    final mnemonic = await _settingsService.getMnemonic();

    if (mnemonic == null || mnemonic.isEmpty) {
      logger.warn('No passphrase is set. Use "wallet set-passphrase" first.');
      return ExitCode.unavailable.code;
    }

    try {
      final walletInfo = await _substrateService.generateWalletFromSeed(mnemonic);
      logger.info('Address: ${walletInfo.accountId}');
      return ExitCode.success.code;
    } catch (e) {
      logger.err('Failed to derive address from passphrase: $e');
      return ExitCode.software.code;
    }
  }
}
