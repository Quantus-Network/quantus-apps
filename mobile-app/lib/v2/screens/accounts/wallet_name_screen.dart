import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/name_field.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';

/// Names (or renames) a wallet. The name is optional: saving an empty field
/// clears it and the wallet falls back to its "Wallet {n}" display name.
class WalletNameScreen extends ConsumerStatefulWidget {
  const WalletNameScreen({super.key, required this.walletIndex, this.returnHighlightAccountId});

  final int walletIndex;

  /// When set (post-import), Done returns to the Accounts screen highlighting
  /// this account instead of popping back to the previous screen.
  final String? returnHighlightAccountId;

  @override
  ConsumerState<WalletNameScreen> createState() => _WalletNameScreenState();
}

class _WalletNameScreenState extends ConsumerState<WalletNameScreen> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: SettingsService().getWalletName(widget.walletIndex) ?? '');
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await SettingsService().setWalletName(widget.walletIndex, _controller.text.trim());
    ref.invalidate(walletNameProvider(widget.walletIndex));
    if (!mounted) return;
    final highlightAccountId = widget.returnHighlightAccountId;
    if (highlightAccountId != null) {
      returnToAccountsScreen(context, ref, highlightAccountId: highlightAccountId);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.walletNameTitle, showBackButton: widget.returnHighlightAccountId == null),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [NameField(controller: _controller, hint: l10n.walletNameHint)],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.walletNameSubtitle,
              style: context.themeText.smallParagraph?.copyWith(color: context.colors.textTertiary),
            ),
            const SizedBox(height: 24),
            QuantusButton.simple(label: l10n.commonDone, onTap: _save, isLoading: _saving),
          ],
        ),
      ),
    );
  }
}
