import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/public_key_export_screen.dart';

class ShowKeyScreen extends ConsumerWidget {
  /// The account to show; defaults to the wallet's first.
  final String? address;

  const ShowKeyScreen({super.key, this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final address = this.address ?? ref.watch(addressProvider);
    final checkphrase = address == null ? const AsyncValue<String>.data('') : ref.watch(checksumNameProvider(address));
    final account = address == null ? null : ref.watch(addressesProvider)[address];

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Show Key'),
      mainContent: address == null
          ? const Center(child: Loader(size: 24))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Scan with your Quantus hot wallet to add this account.',
                    style: text.body.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Center(child: QuantusQr(accountId: address)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
                    child: Text(
                      address,
                      style: text.dataAddressLarge.copyWith(color: colors.textContent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  checkphrase.when(
                    data: (phrase) => Text(
                      phrase,
                      style: text.headingRow.copyWith(color: colors.semanticLilac),
                      textAlign: TextAlign.center,
                    ),
                    loading: () => const Loader(size: 16),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  if (account?.scheme == DilithiumScheme.mlDsa65) _publicKeySection(context, ref, address),
                ],
              ),
            ),
    );
  }

  /// The full key is only useful where a key is registered directly rather
  /// than by Quantus address, and ML-DSA-65 is the one scheme such a system
  /// (NEAR) accepts today, so only those accounts offer it. The key pair is
  /// derived on tap, not on build.
  Widget _publicKeySection(BuildContext context, WidgetRef ref, String address) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PUBLIC KEY', style: text.labelMonogram.copyWith(color: colors.accentFlare, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
            'The address above is a hash of this account\'s key. Systems that register the key itself, such as '
            'NEAR, need the full public key; transactions they send for it are then reviewed and signed here.',
            style: text.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          QuantusButton.simple(
            label: 'Show public key',
            variant: ButtonVariant.staged,
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
      ),
    );
  }
}
