import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';

/// Every call the signer can be asked to review, one tap from its review
/// screen — the simulator stand-in for scanning a QR per transaction type.
///
/// Signed for the wallet's own first account, because the review screen refuses
/// a request naming an account this wallet does not hold.
class DebugCallsScreen extends ConsumerWidget {
  const DebugCallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final signer = ref.watch(addressProvider);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Debug calls'),
      mainContent: signer == null
          ? Center(
              child: Text(
                'Unlock the wallet first — a debug payload is signed by its first account.',
                style: text.body.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              children: [
                for (final entry in DebugPayloads.byPallet.entries) ...[
                  _header(context, '${entry.key.toUpperCase()} · ${entry.value.length}', colors.accentFlare),
                  for (final call in entry.value) _row(context, call, signer),
                ],
                _header(context, 'REFUSED · ${DebugPayloads.refused.length}', colors.semanticEmber),
                for (final call in DebugPayloads.refused) _row(context, call, signer),
                _header(context, 'INVALID QR CODE DATA · ${DebugPayloads.invalidQrData.length}', colors.semanticEmber),
                for (final call in DebugPayloads.invalidQrData) _row(context, call, signer),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _header(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(title, style: context.themeTextV3.labelMonogram.copyWith(color: color, letterSpacing: 1.2)),
    );
  }

  Widget _row(BuildContext context, DebugCall call, String signer) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignTransactionScreen(
            request: SigningRequest(signer: call.signer ?? signer, payload: DebugPayloads.payloadForCall(call.call)),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderHairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(call.label, style: text.body.copyWith(color: colors.textContent)),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
