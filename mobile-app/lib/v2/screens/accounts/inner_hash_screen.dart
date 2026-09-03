import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/copyable_data_item.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/share_account_button.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';

/// Inner hash of the encrypted account's current receive address: the value a
/// miner passes as `--rewards-inner-hash` so block rewards land on this account.
class InnerHashScreen extends ConsumerStatefulWidget {
  const InnerHashScreen({super.key, required this.walletIndex});

  final int walletIndex;

  @override
  ConsumerState<InnerHashScreen> createState() => _InnerHashScreenState();
}

class _InnerHashScreenState extends ConsumerState<InnerHashScreen> {
  String? _innerHash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final keyPair = await ref.read(encryptedAccountServiceProvider(widget.walletIndex)).receiveKeyPair();
      if (mounted) setState(() => _innerHash = keyPair.rewardsPreimageHex);
    } catch (e, st) {
      quantusPrint('[InnerHashScreen] load failed: $e\n$st');
      if (mounted) context.showErrorToaster(message: ref.read(l10nProvider).innerHashLoadError);
    }
  }

  void _share() {
    final innerHash = _innerHash;
    if (innerHash == null) return;
    shareText(context, innerHash);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.innerHashTitle),
      mainContent: SplitCard.single(
        child: CopyableDataItem(
          label: l10n.innerHashLabel,
          value: _innerHash ?? l10n.commonLoading,
          copiedMessage: l10n.innerHashCopied,
          enabled: _innerHash != null,
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: ShareAccountButton(onTap: _share, isDisabled: _innerHash == null),
      ),
    );
  }
}
