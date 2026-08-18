import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/preimage.dart' as preimage_pallet;
import 'package:quantus_sdk/generated/planck/pallets/recovery.dart' as recovery_pallet;
import 'package:quantus_sdk/generated/planck/pallets/reversible_transfers.dart' as reversible_pallet;
import 'package:quantus_sdk/generated/planck/pallets/system.dart' as system_pallet;
import 'package:quantus_sdk/generated/planck/pallets/tech_collective.dart' as collective_pallet;
import 'package:quantus_sdk/generated/planck/pallets/utility.dart' as utility_pallet;
import 'package:quantus_sdk/generated/planck/pallets/vesting.dart' as vesting_pallet;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/src/chain/call_decoder.dart';
import 'package:quantus_sdk/src/chain/call_policy.dart';

RuntimeCall transfer() => const balances_pallet.Txs().transferAllowDeath(dest: _bob, value: _one);
final _bob = multi_address.MultiAddress.values.id(Uint8List.fromList(List.filled(32, 0xBB)));
final _one = BigInt.from(1000000000000);

void expectAllowed(RuntimeCall call, {List<CallId> within = const []}) {
  CallDecoder.decodeBytes(call.encode(), policy: const WalletCallPolicy(), within: within);
}

void expectRejected(RuntimeCall call, {List<CallId> within = const []}) {
  expect(
    () => CallDecoder.decodeBytes(call.encode(), policy: const WalletCallPolicy(), within: within),
    throwsA(isA<FormatException>()),
    reason: '${call.toJson()}',
  );
}

void main() {
  group('CallId', () {
    test('reads its indices and name off the runtime encoder', () {
      final call = transfer();
      final id = CallId.of(call);

      expect(id.pallet, call.encode()[0]);
      expect(id.call, call.encode()[1]);
      expect(id.name, 'Balances.transfer_allow_death');
    });

    test('compares by index, so a wire id matches a named one', () {
      final id = CallIds.transferAllowDeath;
      expect(CallId.wire(id.pallet, id.call), id);
    });
  });

  group('FullCallPolicy', () {
    final everything = <RuntimeCall>[
      transfer(),
      const balances_pallet.Txs().transferAll(dest: _bob, keepAlive: false),
      const collective_pallet.Txs().vote(poll: 1, aye: true),
      const preimage_pallet.Txs().notePreimage(bytes: [0, 0, 0]),
      const system_pallet.Txs().remark(remark: [1, 2, 3]),
      const vesting_pallet.Txs().claim(scheduleId: BigInt.one),
      const recovery_pallet.Txs().removeRecovery(),
      const utility_pallet.Txs().batchAll(calls: [transfer()]),
    ];

    for (final call in everything) {
      test('accepts ${call.toJson().keys.first}', () {
        CallDecoder.decodeBytes(call.encode(), policy: const FullCallPolicy());
      });
    }
  });

  group('WalletCallPolicy at the top level', () {
    test('accepts the transfers the wallet builds', () {
      expectAllowed(transfer());
      expectAllowed(const balances_pallet.Txs().transferKeepAlive(dest: _bob, value: _one));
      expectAllowed(const balances_pallet.Txs().transferAll(dest: _bob, keepAlive: false));
      expectAllowed(const reversible_pallet.Txs().scheduleTransfer(dest: _bob, amount: _one));
    });

    test('accepts the multisig lifecycle', () {
      expectAllowed(const multisig_pallet.Txs().cancel(multisigAddress: _alice, proposalId: 1));
      expectAllowed(const multisig_pallet.Txs().execute(multisigAddress: _alice, proposalId: 1));
      expectAllowed(const multisig_pallet.Txs().claimDeposits(multisigAddress: _alice));
    });

    test('rejects everything the wallet cannot build', () {
      expectRejected(const collective_pallet.Txs().vote(poll: 1, aye: true));
      expectRejected(const system_pallet.Txs().remark(remark: [1]));
      expectRejected(const preimage_pallet.Txs().notePreimage(bytes: [0, 0, 0]));
      expectRejected(const vesting_pallet.Txs().claim(scheduleId: BigInt.one));
      expectRejected(const recovery_pallet.Txs().removeRecovery());
    });

    test('rejects a bare batch_all outside a proposal', () {
      expectRejected(const utility_pallet.Txs().batchAll(calls: [transfer()]));
    });
  });

  group('WalletCallPolicy inside a multisig proposal', () {
    test('accepts a transfer', () {
      expectAllowed(transfer(), within: CallIds.insideProposal);
    });

    test('accepts batch_all of transfers only', () {
      expectAllowed(
        const utility_pallet.Txs().batchAll(calls: [transfer(), transfer()]),
        within: CallIds.insideProposal,
      );
      expectRejected(
        const utility_pallet.Txs().batchAll(
          calls: [
            transfer(),
            const system_pallet.Txs().remark(remark: [1]),
          ],
        ),
        within: CallIds.insideProposal,
      );
    });

    test('rejects a nested batch_all', () {
      expectRejected(
        const utility_pallet.Txs().batchAll(
          calls: [
            const utility_pallet.Txs().batchAll(calls: [transfer()]),
          ],
        ),
        within: CallIds.insideProposal,
      );
    });

    test('rejects a proposal carrying governance or a remark', () {
      expectRejected(const collective_pallet.Txs().vote(poll: 1, aye: true), within: CallIds.insideProposal);
      expectRejected(const system_pallet.Txs().remark(remark: [1]), within: CallIds.insideProposal);
    });
  });

  group('the policy runs before arguments are read', () {
    test('a rejected call is refused without decoding its arguments', () {
      final vote = const collective_pallet.Txs().vote(poll: 1, aye: true).encode();
      expect(
        () => CallDecoder.decodeBytes([vote[0], vote[1]], policy: const WalletCallPolicy()),
        throwsA(isA<CallRejectedException>()),
      );
    });

    test('a batch claiming more calls than the bytes can hold is refused', () {
      final batchAll = CallIds.batchAll;
      expect(
        () => CallDecoder.decodeBytes([
          batchAll.pallet,
          batchAll.call,
          0xFC,
          0xFF,
          0xFF,
          0xFF,
        ], policy: const FullCallPolicy()),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('a rejection reports what it knows', () {
    test('the refused indices and the chain it was refused inside', () {
      final remark = const system_pallet.Txs().remark(remark: [1]).encode();
      expect(
        () => CallDecoder.decodeBytes(remark, policy: const WalletCallPolicy(), within: CallIds.insideProposal),
        throwsA(
          isA<CallRejectedException>().having(
            (e) => e.message,
            'message',
            allOf(contains('pallet ${remark[0]} call ${remark[1]}'), contains('Multisig.propose')),
          ),
        ),
      );
    });
  });
}

const _alice = <int>[
  0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, //
  0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
  0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
  0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
];
