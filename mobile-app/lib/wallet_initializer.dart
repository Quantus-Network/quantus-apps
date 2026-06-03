import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/migration_dialog.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/logout_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/env_utils.dart';

class WalletInitializer extends ConsumerStatefulWidget {
  const WalletInitializer({super.key});

  @override
  ConsumerState<WalletInitializer> createState() => WalletInitializerState();
}

class WalletInitializerState extends ConsumerState<WalletInitializer> {
  bool _loading = true;
  bool _walletExists = false;
  bool _needsMigration = false;
  List<MigrationAccountData>? _migrationData;
  final SettingsService _settingsService = SettingsService();
  late final MigrationService _migrationService;

  @override
  void initState() {
    super.initState();
    _migrationService = MigrationService(_settingsService, HdWalletService());
    _checkWalletAndMigration();
  }

  Future<void> _checkWalletAndMigration() async {
    final hasWallet = await _settingsService.getHasWallet();

    if (hasWallet) {
      final mnemonic = await _settingsService.getMnemonic(0);
      if (mnemonic == null) {
        TelemetryService().sendEvent('user_lost_mnemonic');
        if (mounted) await _showMnemonicLostDialog();
        return;
      }
    }

    final needsMigration = _migrationService.needsMigration();

    if (needsMigration) {
      try {
        final migrationData = await _migrationService.getMigrationData();

        for (final data in migrationData) {
          quantusDebugPrint(
            'MIGRATION: \nold index: ${data.oldAccount.index} \nold name: ${data.oldAccount.name} \nold accountId: ${data.oldAccount.accountId} \nnew accountId: ${data.newAccountId}',
          );
        }
        setState(() {
          _needsMigration = true;
          _migrationData = migrationData;
          _loading = false;
        });

        // Show migration dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          MigrationDialog.show(
            context: context,
            migrationData: _migrationData!,
            onMigrate: _performMigration,
            onTryLater: _tryLater,
          );
        });
      } catch (e) {
        // If migration data can't be loaded, continue without migration
        setState(() {
          _walletExists = hasWallet;
          _loading = false;
        });
      }
    } else {
      setState(() {
        _walletExists = hasWallet;
        _loading = false;
      });
    }
  }

  Future<void> _showMnemonicLostDialog() async {
    final l10n = ref.read(l10nProvider);

    await BottomSheetContainer.show(
      context,
      builder: (ctx) => BottomSheetContainer(
        title: l10n.walletInitErrorTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.walletInitErrorMessage, style: ctx.themeText.smallParagraph),
            const SizedBox(height: 32),
            QuantusButton.simple(
              label: l10n.walletInitErrorButtonLabel,
              onTap: () => Navigator.pop(ctx),
              variant: ButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
    if (mounted) ref.read(logoutServiceProvider).logout(context);
  }

  void _reloadAccounts() {
    ref.invalidate(accountsProvider);
    ref.invalidate(activeAccountProvider);
  }

  Future<void> _performMigration() async {
    if (_migrationData == null) return;

    try {
      // First, upload migration data to Supabase
      await _uploadMigrationDataToSupabase(_migrationData!);

      // Then perform the actual migration
      await _migrationService.performMigration(_migrationData!);

      _reloadAccounts();
      // Migration completed successfully. Update state to show the main app.
      setState(() {
        _needsMigration = false;
        _walletExists = true;
        _loading = false;
      });
    } catch (e) {
      quantusDebugPrint('migration error: $e');
      rethrow;
    }
  }

  Future<void> _tryLater() async {
    // Persist the old accounts so we can retry upload later from settings
    final oldAccounts = _settingsService.getOldAccounts();
    await _settingsService.setAccountsToMigrate(oldAccounts);

    // Proceed with local migration immediately
    if (_migrationData != null) {
      try {
        await _migrationService.performMigration(_migrationData!);
      } catch (e, stackTrace) {
        quantusDebugPrint('error in tryLater: $e');
        quantusDebugPrint('stack trace: $stackTrace');
        TelemetryService().sendError('Error-Migration-TryLater', error: e, stackTrace: stackTrace);
        rethrow;
      }
    }

    _reloadAccounts();

    if (!mounted) return;
    setState(() {
      _needsMigration = false;
      _walletExists = true;
      _loading = false;
    });
  }

  Future<void> _uploadMigrationDataToSupabase(List<MigrationAccountData> migrationData) async {
    quantusDebugPrint('_uploadMigrationDataToSupabase');
    final supabase = EnvUtils.supabaseClient;

    try {
      // Prepare the data for insertion
      final dataToInsert = migrationData
          .map(
            (data) => {
              'old_account_id': data.oldAccount.accountId,
              'new_account_id': data.newAccountId,
              'public_key_hex': data.publicKeyHex,
            },
          )
          .toList();

      quantusDebugPrint('uploading data to supabase: $dataToInsert');

      // Insert all records at once
      await supabase.from('account_id_mappings').insert(dataToInsert);

      quantusDebugPrint('Successfully uploaded ${migrationData.length} migration records to Supabase');
    } catch (e) {
      quantusDebugPrint('Failed to upload migration data to Supabase: $e');
      // Re-throw the error so it gets caught by the caller
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ScaffoldBase(mainContent: Center(child: CircularProgressIndicator()));
    }

    if (_needsMigration) {
      return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: const SizedBox.shrink());
    }

    if (_walletExists) {
      return const HomeScreen();
    } else {
      return const WelcomeScreenV2();
    }
  }
}
