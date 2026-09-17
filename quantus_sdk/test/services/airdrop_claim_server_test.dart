// Drives real claims through the SDK against a locally built airdrop-claim
// server (github.com/Quantus-Network/airdrop-claim), so the wire contract is
// checked end to end: matching, ML-DSA-87 claim signing, the wormhole
// ownership proof, and the server's verification and bookkeeping.
//
//   (in airdrop-claim)  cargo build --release --bin airdrop-check
//   (in quantus_sdk)    AIRDROP_CHECK_BIN=.../target/release/airdrop-check \
//                       flutter test test/services/airdrop_claim_server_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';
final _server = Uri.parse('http://127.0.0.1:18081');

void main() {
  final bin = Platform.environment['AIRDROP_CHECK_BIN'];

  test(
    'a Dilithium and a wormhole miner are matched, proved, recorded; a retry changes nothing; another payout address is refused',
    () async {
      await RustLib.init();
      setDefaultSs58Prefix(prefix: 189);
      final hd = HdWalletService();
      final miner = hd.keyPairAtIndex(_mnemonic, 0, DilithiumScheme.mlDsa87).ss58Address;
      final wormhole = hd.deriveWormholeKeyPair(mnemonic: _mnemonic).address;
      final beneficiary = hd.keyPairAtIndex(_mnemonic, 1, DilithiumScheme.mlDsa87).ss58Address;

      final dir = await Directory.systemTemp.createTemp('airdrop-claim-');
      final snapshot = File('${dir.path}/snapshot.csv')
        ..writeAsStringSync('Address,Total Mining Rewards,Testnet\n$miner,1.50,Dirac\n$wormhole,2.00,Planck\n');
      final server = await Process.start(bin!, [
        '--snapshot',
        snapshot.path,
        'serve',
        '--bind',
        '${_server.host}:${_server.port}',
        '--db',
        '${dir.path}/claims.sqlite',
      ], mode: ProcessStartMode.inheritStdio);
      addTearDown(() {
        server.kill();
        dir.deleteSync(recursive: true);
      });
      await _untilListening();

      final matches = await findAirdropMatches(
        snapshotAddresses: [miner, wormhole],
        mnemonic: _mnemonic,
        extraWormholeSecrets: const [],
      );
      expect(
        matches.map((m) => (m.address, m.kind, m.claimable)),
        unorderedEquals([(miner, 'dilithium', true), (wormhole, 'wormhole', true)]),
      );

      final claims = AirdropClaimService(endpoint: _server.toString());
      await claims.submitClaims(matches: matches, mnemonic: _mnemonic, claimAccount: beneficiary);

      final unpaid = jsonDecode((await http.get(_server.resolve('/unpaid'))).body) as Map<String, dynamic>;
      expect(unpaid['total_amount_hundredths'], 350);
      expect([
        for (final r in unpaid['rows']) (r['address'], r['status'], r['claim_account'], r['amount_hundredths']),
      ], unorderedEquals([(miner, 'recorded', beneficiary, 150), (wormhole, 'recorded', beneficiary, 200)]));

      // A retry finds both addresses already recorded and neither fails nor re-records.
      await claims.submitClaims(matches: matches, mnemonic: _mnemonic, claimAccount: beneficiary);
      final again = jsonDecode((await http.get(_server.resolve('/unpaid'))).body) as Map<String, dynamic>;
      expect(again['rows'], unpaid['rows']);

      // Re-claiming to a different payout address is refused, naming the recorded one.
      final other = hd.keyPairAtIndex(_mnemonic, 2, DilithiumScheme.mlDsa87).ss58Address;
      await expectLater(
        claims.submitClaims(matches: matches, mnemonic: _mnemonic, claimAccount: other),
        throwsA(
          isA<AirdropClaimFailure>().having(
            (f) => f.cause,
            'cause',
            isA<AirdropClaimTaken>().having((t) => t.recordedTo, 'recordedTo', beneficiary),
          ),
        ),
      );
    },
    skip: bin == null ? 'set AIRDROP_CHECK_BIN to a built airdrop-check binary' : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _untilListening() async {
  for (var i = 0; i < 50; i++) {
    try {
      if ((await http.get(_server.resolve('/snapshot'))).statusCode == 200) return;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  throw StateError('airdrop-check did not start listening on $_server');
}
