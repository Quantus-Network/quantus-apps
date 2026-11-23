import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
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
  final _buttonKey = GlobalKey();
  bool _isLoading = false;
  String? _error;

  bool get _hasInput => _controller.text.trim().isNotEmpty;

  Future<void> _import() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final root = await importSoftwareWallet(
        ref,
        mnemonic: _controller.text,
        walletIndex: widget.walletIndex,
        onScanFailed: _askRetryScan,
      );

      if (!mounted) return;
      if (widget.openAccountsOnComplete) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WalletNameScreen(walletIndex: widget.walletIndex, returnHighlightAccountId: root.accountId),
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

  Future<bool> _askRetryScan(Object error) async {
    if (!mounted) return false;
    final l10n = ref.read(l10nProvider);
    return showQuantusDialog(
      context,
      title: l10n.importWalletScanFailedTitle,
      body: l10n.importWalletScanFailedBody,
      actionLabel: l10n.importWalletScanRetry,
      cancelLabel: l10n.importWalletScanSkip,
      barrierDismissible: false,
    );
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
              QuantusSeedPhraseField(
                key: const Key(E2EKeys.importWalletSeedPhraseField),
                controller: _controller,
                hint: l10n.importWalletHint,
                onChanged: (_) => setState(() {}),
                scrollToOnFocus: _buttonKey,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: text.caption.copyWith(color: colors.semanticEmber),
                  textAlign: TextAlign.center,
                ),
              ],
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
    _controller.dispose();
    super.dispose();
  }
}
