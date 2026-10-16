import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/anchored_menu.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/enlarged_qr_screen.dart';
import 'package:quantus_cold_wallet/screens/public_key_export_screen.dart';
import 'package:quantus_cold_wallet/screens/rename_account_screen.dart';
import 'package:quantus_cold_wallet/components/cold_button.dart';
import 'package:quantus_cold_wallet/components/cold_dialog.dart';

/// Account Pairing (Figma Cold Wallet): the QR a hot wallet scans to add this
/// account, with its address and checkphrase.
class ShowKeyScreen extends ConsumerWidget {
  final String address;

  const ShowKeyScreen({super.key, required this.address});

  void _openMenu(BuildContext context, BuildContext anchor, WidgetRef ref, ColdAccount account) {
    showAnchoredMenu(
      context,
      anchor: anchor,
      width: 234,
      groups: [
        [
          AnchoredMenuItem(
            label: 'Show full screen',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EnlargedQrScreen(address: address, label: account.label),
              ),
            ),
          ),
          AnchoredMenuItem(label: 'Show derivation path', onTap: () => _showDerivationPath(context, account)),
          renameMenuItem(context, account),
        ],
        [disconnectMenuItem(context, ref, account, afterRemove: () => Navigator.pop(context))],
      ],
    );
  }

  void _showDerivationPath(BuildContext context, ColdAccount account) {
    final colors = context.colorsV3;
    showColdDialog(
      context,
      title: 'Derivation Path',
      titleColor: colors.accentFlare,
      banner: Text(
        account.derivationPath,
        style: context.themeTextV3.dataAddressLarge.copyWith(color: colors.textContent),
        textAlign: TextAlign.center,
      ),
      body:
          'You need this to recreate the account on another wallet. It is not a secret and it is not enough to '
          'spend anything.',
      actionLabel: 'Done',
      cancelLabel: null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = ref.watch(addressesProvider)[address];
    if (account == null) return const ScaffoldBase(mainContent: SizedBox.shrink());
    final checkphrase = ref.watch(checksumNameProvider(address));

    return ScaffoldBase(
      appBar: V2AppBar(
        title: account.label,
        trailing: Builder(builder: (anchor) => KebabButton(onTap: () => _openMenu(context, anchor, ref, account))),
      ),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Scan this with Quantus on your other phone.',
              style: text.bodyLarge.copyWith(color: colors.textContent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(child: QuantusQr(accountId: address)),
            const SizedBox(height: 24),
            _Card(
              children: [
                DetailSummaryRow.stacked(label: 'Address', value: address, monospace: true),
                checkphrase.when(
                  data: (phrase) => DetailSummaryRow.stacked(
                    label: 'Checkphrase',
                    value: phrase,
                    monospace: true,
                    valueColor: colors.semanticLilac,
                  ),
                  loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Loader(size: 16)),
                  error: (e, _) {
                    debugPrint('Checkphrase failed for $address: $e');
                    return DetailSummaryRow.stacked(
                      label: 'Checkphrase',
                      value: 'Could not derive the checkphrase.',
                      valueColor: colors.semanticEmber,
                    );
                  },
                ),
              ],
            ),
            if (account.scheme == DilithiumScheme.mlDsa65) ...[
              const SizedBox(height: 16),
              _publicKeySection(context, ref),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// The full key is only useful where a key is registered directly rather
  /// than by Quantus address, and ML-DSA-65 is the one scheme such a system
  /// (NEAR) accepts today, so only those accounts offer it. The key pair is
  /// derived on tap, not on build.
  Widget _publicKeySection(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return _Card(
      children: [
        Text('PUBLIC KEY', style: text.labelMonogram.copyWith(color: colors.accentFlare, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text(
          'The address above is a hash of this account\'s key. Systems that register the key itself, such as '
          'NEAR, need the full public key; transactions they send for it are then reviewed and signed here.',
          style: text.caption.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 16),
        ColdButton.secondary(
          label: 'Show public key',
          onTap: () {
            final keypair = keypairFor(ref, address);
            if (keypair == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublicKeyExportScreen(
                  export: NearPublicKeyExport(
                    address: address,
                    nearPublicKey: nearPublicKeyText(keypair: keypair),
                  ),
                  handle: nearPublicKeyHandle(keypair: keypair),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Kebab glyph with a 44pt target, for an app bar slot or a list row.
class KebabButton extends StatelessWidget {
  final VoidCallback onTap;

  const KebabButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: QuantusIcon(QuantusIcons.kebab, size: 20, color: context.colorsV3.textContent)),
      ),
    );
  }
}

AnchoredMenuItem renameMenuItem(BuildContext context, ColdAccount account) => AnchoredMenuItem(
  label: 'Rename',
  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RenameAccountScreen(account: account))),
);

/// Inert for the only account: the wallet refuses to drop it.
AnchoredMenuItem disconnectMenuItem(
  BuildContext context,
  WidgetRef ref,
  ColdAccount account, {
  VoidCallback? afterRemove,
}) {
  final isLast = ref.read(accountsProvider).length <= 1;
  return AnchoredMenuItem(
    label: 'Disconnect account',
    isDestructive: true,
    caption: isLast ? 'This is the only account in this wallet, so it cannot be disconnected.' : null,
    onTap: isLast ? null : () => confirmDisconnect(context, ref, account, afterRemove: afterRemove),
  );
}

/// Disconnect dialog (Figma Cold Wallet / Disconnect). On confirm the account
/// is dropped, [afterRemove] runs, and the screen left showing gets the toast.
Future<void> confirmDisconnect(
  BuildContext context,
  WidgetRef ref,
  ColdAccount account, {
  VoidCallback? afterRemove,
}) async {
  final mnemonic = ref.read(walletControllerProvider).mnemonic ?? (throw StateError('Wallet is locked'));
  final words = mnemonic.split(' ').length;
  final confirmed = await showColdDialog(
    context,
    title: 'Disconnect ${account.label}?',
    titleColor: context.colorsV3.semanticEmber,
    body: 'This device forgets the account. Nothing on the network changes, and your $words words bring it back.',
    actionLabel: 'Disconnect',
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(walletControllerProvider.notifier).removeAccount(account);
  } catch (e) {
    debugPrint('Disconnect account failed: $e');
    if (context.mounted) context.showErrorToaster(message: 'Could not disconnect ${account.label}: $e');
    return;
  }
  if (!context.mounted) return;
  afterRemove?.call();
  context.showInfoToaster(message: '${account.label} disconnected');
}
