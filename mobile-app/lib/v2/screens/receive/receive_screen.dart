import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  String? _accountId;
  String? _checksum;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    final settingsService = ref.read(settingsServiceProvider);
    final checksumService = ref.read(humanReadableChecksumServiceProvider);

    try {
      final account = (await settingsService.getActiveAccount())!;
      var accountId = account.account.accountId;
      // Encrypted accounts rotate deposits to the next unused wormhole address
      // (shared linearly with change addresses) so deposits aren't linkable.
      final base = account.account;
      if (isEncryptedAccount(base)) {
        final service = ref.read(encryptedAccountServiceProvider((base as Account).walletIndex));
        accountId = (await service.receiveKeyPair()).address;
      }
      // Degrade to a blank checkphrase on lookup failure so the address/QR
      // still renders instead of an unbounded loader.
      final checksum = await checksumService.getHumanReadableName(accountId) ?? '';
      if (!mounted) return;
      setState(() {
        _accountId = accountId;
        _checksum = checksum;
      });
    } catch (e) {
      quantusPrint('Error loading account data: $e');

      if (mounted) {
        final l10n = ref.read(l10nProvider);
        context.showErrorToaster(message: l10n.receiveErrorLoadingAccount('$e'));
      }
    }
  }

  void _share() {
    if (_accountId != null && _checksum != null) {
      shareAccountDetails(context, _accountId!, checksum: _checksum!);
    }
  }

  void _copyAddress(BuildContext context) {
    final l10n = ref.read(l10nProvider);
    context.copyTextWithToaster(_accountId!, message: l10n.receiveCopiedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final isLoading = _accountId == null || _checksum == null;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.receiveTitle),
      mainContent: isLoading
          ? const Center(child: Loader())
          : SingleChildScrollView(
              child: _ReceiveDetails(
                accountId: _accountId!,
                checksum: _checksum!,
                addressLabel: l10n.receiveYourAddressLabel,
                checkphraseLabel: l10n.componentCheckphraseLabel,
                footnote: l10n.receiveCheckphraseFootnote,
              ),
            ),
      bottomContent: isLoading
          ? null
          : ScaffoldBaseBottomContent(
              child: Column(
                children: [
                  QuantusButton.simple(label: l10n.receiveCopyAddress, onTap: () => _copyAddress(context)),
                  const SizedBox(height: 16),
                  QuantusButton.simple(label: l10n.componentShare, onTap: _share, variant: ButtonVariant.staged),
                ],
              ),
            ),
    );
  }
}

class _ReceiveDetails extends StatelessWidget {
  const _ReceiveDetails({
    required this.accountId,
    required this.checksum,
    required this.addressLabel,
    required this.checkphraseLabel,
    required this.footnote,
  });

  final String accountId;
  final String checksum;
  final String addressLabel;
  final String checkphraseLabel;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      children: [
        QuantusQr(accountId: accountId),
        const SizedBox(height: 20),
        SizedBox(
          width: 240,
          child: _LabeledValue(
            label: addressLabel,
            value: accountId,
            valueStyle: text.dataAddressLarge.copyWith(color: colors.textWhite),
          ),
        ),
        const SizedBox(height: 20),
        _LabeledValue(
          label: checkphraseLabel,
          value: checksum,
          valueStyle: text.dataAddressLarge.copyWith(color: colors.semanticLilac),
          footnote: footnote,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value, required this.valueStyle, this.footnote});

  final String label;
  final String value;
  final TextStyle valueStyle;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      children: [
        Text(
          label,
          style: text.labelData.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 9),
        Text(value, style: valueStyle, textAlign: TextAlign.center),
        if (footnote != null) ...[
          const SizedBox(height: 9),
          SizedBox(
            width: 240,
            child: Text(
              footnote!,
              style: text.caption.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
