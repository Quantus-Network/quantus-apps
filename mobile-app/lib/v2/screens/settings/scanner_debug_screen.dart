import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:wallet_core/providers/account_providers.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signature_scan_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';

/// Debug builds only: every scanner screen in the app, opened without the
/// cold wallet or the transaction it normally needs. The signature rows run
/// the real step 3/3 screen on a stand-in transaction and a blank signature;
/// nothing is signed or broadcast.
class ScannerDebugScreen extends ConsumerWidget {
  static const title = 'Scanner test harness';
  static const subtitle = 'Debug only: open every scanner screen';

  const ScannerDebugScreen({super.key});

  /// Era period 0 keeps the screen off the network; the registry is only read
  /// when a payload is encoded, which the harness never does.
  static UnsignedTransactionData _unsignedData() => UnsignedTransactionData(
    payloadToSign: QuantusSigningPayload(
      method: Uint8List(0),
      specVersion: 0,
      transactionVersion: 0,
      genesisHash: '0x${'00' * 32}',
      blockHash: '0x${'00' * 32}',
      blockNumber: 0,
      eraPeriod: 0,
      nonce: 0,
      tip: 0,
    ),
    signer: Uint8List(32),
    registry: null,
  );

  static Future<List<String>> _signatureParts() async =>
      encodeUr(data: Uint8List(DilithiumScheme.mlDsa87.signatureWithPublicKeyBytes), maxFragmentLength: 100);

  static KeystoneSignatureScanScreen _signatureScan(Account account, {required bool fails}) =>
      KeystoneSignatureScanScreen(
        unsignedData: _unsignedData(),
        debugSignatureParts: _signatureParts,
        session: KeystoneSigningSession(
          account: account,
          telemetryPrefix: 'debug_scanner',
          buildCall: () => throw StateError('The scanner harness builds no call'),
          submitSigned: (ref, {required unsignedData, required signatureWithPublicKey}) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            if (fails) throw StateError('Scanner harness: simulated submission failure');
            return '0x';
          },
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAccountProvider).value;
    final account = active is RegularAccount ? active.account : null;

    Widget row(String name, String description, Widget Function() screen) => SettingsTappableRow(
      title: name,
      subtitle: description,
      trailing: SettingsTappableRowUtils.chevron(),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen())),
    );

    return ScaffoldBase(
      appBar: const V2AppBar(title: title),
      mainContent: ListView(
        children: [
          const SettingsDivider(),
          row(
            'Address scanner',
            'Send, Add Cold Wallet and the swap address field all open this',
            () => const QrScannerPage(),
          ),
          const SettingsDivider(),
          if (account == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Select a regular account to open the cold wallet signature scanner',
                style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted),
              ),
            )
          else ...[
            row(
              'Cold wallet signature',
              'Sign with Cold Wallet step 3/3. Simulate fills the progress, then submits',
              () => _signatureScan(account, fails: false),
            ),
            const SettingsDivider(),
            row(
              'Cold wallet signature, submission fails',
              'Same scan, then the error above the progress bar',
              () => _signatureScan(account, fails: true),
            ),
            const SettingsDivider(),
          ],
        ],
      ),
    );
  }
}
