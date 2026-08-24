import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_reject_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signature_scan_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_widgets.dart';

/// Step 2/3 of Keystone signing: shows what the device screen should display,
/// so the user can compare before approving on the Keystone.
///
/// Pops with the submitted extrinsic hash, `false` when the user rejected the
/// transaction on the device, or null when simply navigating back.
class KeystoneVerifyScreen extends ConsumerWidget {
  final KeystoneSigningSession session;
  final UnsignedTransactionData unsignedData;

  const KeystoneVerifyScreen({super.key, required this.session, required this.unsignedData});

  Future<void> _goToScan(BuildContext context) async {
    final hash = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => KeystoneSignatureScanScreen(session: session, unsignedData: unsignedData),
      ),
    );
    if (hash != null && context.mounted) Navigator.pop(context, hash);
  }

  Future<void> _goToReject(BuildContext context) async {
    final rejected = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const KeystoneRejectScreen()),
    );
    if (rejected == true && context.mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.keystoneSignScreenTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KeystoneStepLabel(current: 2, total: 3),
            const SizedBox(height: 12),
            Text(l10n.keystoneVerifyTitle, style: text.headingRow.copyWith(color: colors.textContent)),
            const SizedBox(height: 8),
            Text(l10n.keystoneVerifyInstruction, style: text.caption.copyWith(color: colors.textMuted)),
            const SizedBox(height: 24),
            _summaryCard(context, l10n, colors, text),
            const SizedBox(height: 24),
            KeystoneWarningCard(text: l10n.keystoneVerifyWarning),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(label: l10n.keystoneSignNext, onTap: () => _goToScan(context)),
            const SizedBox(height: 4),
            QuantusButton.simple(
              label: l10n.keystoneVerifyMismatch,
              variant: ButtonVariant.underline,
              onTap: () => _goToReject(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    final labelStyle = text.labelData.copyWith(color: colors.textMuted);
    final address = session.secondaryDetail?.trim();
    final checksum = session.tertiaryDetail;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.primaryDetail != null) ...[
            Text(l10n.sendReviewAmount.toUpperCase(), style: labelStyle),
            const SizedBox(height: 16),
            Text(session.primaryDetail!, style: text.amountHero.copyWith(color: colors.textContent)),
            const SizedBox(height: 24),
            const MenuDivider(),
            const SizedBox(height: 24),
          ],
          if (address != null) ...[
            Text(l10n.sendReviewTo.toUpperCase(), style: labelStyle),
            const SizedBox(height: 16),
            if (checksum != null)
              AddressCheckphraseWithInitial(recipientChecksum: checksum, recipientAddress: address)
            else
              Text(address, style: text.dataAddressLarge.copyWith(color: colors.textContent)),
          ],
        ],
      ),
    );
  }
}
