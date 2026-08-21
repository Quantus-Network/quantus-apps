import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/wallet_name_screen.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';

class ImportWalletScreenV2 extends ConsumerStatefulWidget {
  const ImportWalletScreenV2({super.key, this.walletIndex = 0, this.openAccountsOnComplete = false});

  final int walletIndex;

  /// When true (in-app add), continues to the wallet naming step and then
  /// returns to the Accounts screen with the imported account pre-selected.
  /// Onboarding leaves this false and goes to Home.
  final bool openAccountsOnComplete;

  @override
  ConsumerState<ImportWalletScreenV2> createState() => _ImportWalletScreenV2State();
}

class _ImportWalletScreenV2State extends ConsumerState<ImportWalletScreenV2> {
  final _controller = ObscuringTextEditingController();
  final _focusNode = FocusNode();
  final _buttonKey = GlobalKey();
  final _settingsService = SettingsService();
  final _accountsService = AccountsService();
  final _discoveryService = AccountDiscoveryService(HdWalletService());
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_revealButton);
  }

  void _revealButton() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = _buttonKey.currentContext;
        if (mounted && ctx != null) {
          // ignore: use_build_context_synchronously
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

  bool get _hasInput => _controller.text.trim().isNotEmpty;

  Future<void> _import() async {
    final accounts = ref.read(accountsProvider).value ?? <Account>[];
    final mnemonic = _controller.text.trim();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Dev seeds (//Crystal Alice etc.) skip word-count validation, but only
      // in debug builds; in release they fail normal mnemonic validation (M8).
      if (!(kDebugMode && mnemonic.startsWith('//'))) {
        final words = mnemonic.split(' ').where((w) => w.isNotEmpty).toList();
        if (words.length != 12 && words.length != 24) {
          throw Exception(ref.read(l10nProvider).importWalletValidationError);
        }
      }

      final key = HdWalletService().keyPairAtIndex(mnemonic, 0);
      await _settingsService.setMnemonic(mnemonic, widget.walletIndex);
      await _accountsService.addAccount(
        Account(
          walletIndex: widget.walletIndex,
          index: 0,
          name: 'Account ${accounts.length + 1}',
          accountId: key.ss58Address,
        ),
      );

      if (!HdWalletService.isDevAccount(mnemonic)) {
        await _discoverAccounts(mnemonic);
      }
      invalidateAccountProviders(ref);
      _settingsService.setReferralCheckCompleted();
      _settingsService.setExistingUserSeenPromoVideo();
      _settingsService.setWalletOrigin(widget.walletIndex, WalletOrigin.imported);
      ref.invalidate(walletOriginProvider(widget.walletIndex));

      unawaited(
        registerForRemoteNotificationsBestEffort(ref, insertAddress: widget.walletIndex > 0 ? key.ss58Address : null),
      );

      if (!mounted) return;
      if (widget.openAccountsOnComplete) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                WalletNameScreen(walletIndex: widget.walletIndex, returnHighlightAccountId: key.ss58Address),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Discovers on-chain HD accounts only. Multisigs are added manually via
  /// Add Account → Discover Multisig.
  Future<void> _discoverAccounts(String mnemonic) async {
    try {
      final discovered = await _discoveryService.discoverAccounts(mnemonic: mnemonic, walletIndex: widget.walletIndex);
      final existing = (await _accountsService.getAccounts()).map((e) => e.accountId).toSet();
      for (final account in discovered) {
        if (!existing.contains(account.accountId)) {
          await _accountsService.addAccount(account);
        }
      }
      invalidateAccountProviders(ref);
      unawaited(_discoverEncryptedAccount());
    } catch (e) {
      quantusPrint('error discovering accounts: $e');
      TelemetryService().sendError('Error discovering accounts', error: e);
    }
  }

  /// Restores the wallet's encrypted account and warms its wormhole address
  /// discovery so UTXOs across receive/change addresses are already found when
  /// the user first opens it. Runs fire-and-forget so import completion never
  /// waits on it; if this screen is disposed first, the accounts sheet
  /// backfills through its own [ensureEncryptedAccounts] pass.
  Future<void> _discoverEncryptedAccount() async {
    try {
      final created = await ensureEncryptedAccounts(ref);
      if (!created || !mounted) return;
      ref.invalidate(accountsProvider);
      await ref.read(encryptedStateProvider(widget.walletIndex).future);
    } catch (e) {
      quantusPrint('encrypted discovery after import failed: $e');
      TelemetryService().sendError('Encrypted discovery after import failed', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      key: const Key(E2EKeys.importWalletScreen),
      appBar: V2AppBar(title: l10n.importWalletAppBarTitle),
      mainContent: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(l10n.importWalletDescription, style: text.body.copyWith(color: colors.textMuted)),
              const SizedBox(height: 16),
              QuantusTextField(
                key: const Key(E2EKeys.importWalletSeedPhraseField),
                controller: _controller,
                focusNode: _focusNode,
                hint: l10n.importWalletHint,
                error: _error,
                height: 202,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                trailing: QuantusIconButton.ghost(
                  onTap: () => setState(() => _controller.obscured = !_controller.obscured),
                  icon: _controller.obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: KeyedSubtree(
          key: const Key(E2EKeys.importWalletButton),
          child: QuantusButton.simple(
            key: _buttonKey,
            label: l10n.importWalletButton,
            onTap: _import,
            isLoading: _isLoading,
            isDisabled: !_hasInput,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_revealButton);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
