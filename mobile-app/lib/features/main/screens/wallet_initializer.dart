import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/migration_dialog.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/utils/env_utils.dart';

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
    final needsMigration = _migrationService.needsMigration();

    if (needsMigration) {
      try {
        final migrationData = await _migrationService.getMigrationData();

        for (final data in migrationData) {
          print(
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
      print('migration error: $e');
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
        print('error in tryLater: $e');
        print('stack trace: $stackTrace');
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
    print('_uploadMigrationDataToSupabase');
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

      print('uploading data to supabase: $dataToInsert');

      // Insert all records at once
      await supabase.from('account_id_mappings').insert(dataToInsert);

      print('Successfully uploaded ${migrationData.length} migration records to Supabase');
    } catch (e) {
      print('Failed to upload migration data to Supabase: $e');
      // Re-throw the error so it gets caught by the caller
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTxIntent = ref.read(transactionIntentProvider) != null;
    // If we have value of tx that means we got arguments from notification tap,
    // so we wanted to display the transactions history screen instead which is index 1.
    final initialIndex = hasTxIntent ? 1 : 0;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If migration is needed, render a neutral background (no spinner) while
    // the bottom sheet is presented, to avoid a loading indicator behind it.
    if (_needsMigration) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (_walletExists) {
      return Navbar(initialIndex: initialIndex);
    } else {
      return const WelcomeScreen();
    }
  }
}
