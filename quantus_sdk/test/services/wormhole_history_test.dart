import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_history.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

const _account = 'qzAccount0';
const _external1 = 'qzExternal1';
const _change0 = 'qzChange0';
const _alice = 'qzAlice';
const _bob = 'qzBob';
const _miner = 'qzMiner';
final _t0 = DateTime.utc(2026, 9, 1, 12);

/// A transfer or exit id in the indexer's `<block>-<hash>-<event index>` form.
String _id(int block, int event) => '${block.toString().padLeft(10, '0')}-00000-${event.toString().padLeft(6, '0')}';

/// A transfer received by this wallet, spendable with [nullifier].
WormholeUtxo _received(
  String nullifier, {
  String to = _account,
  required int scaled,
  String extrinsicId = '0xpay',
  bool viaWormhole = false,
  int block = 1,
  int event = 0,
  DateTime? at,
}) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: _id(block, event),
    blockHeight: block,
    timestamp: at ?? _t0,
    fromId: _bob,
    toId: to,
    amount: wormholeTokenFromScaled(scaled),
    toHash: '',
    leafIndex: BigInt.zero,
    transferCount: BigInt.zero,
    extrinsicId: extrinsicId,
    viaWormhole: viaWormhole,
  ),
  owner: WormholeAddressInfo(index: 0, address: to, secretHex: ''),
  nullifierHex: nullifier,
);

/// A proof extrinsic exiting [outputs] (address → scaled amount), its exits
/// numbered from [event] in [block], settled by [call] (a private batch of
/// this wallet's unless told otherwise).
WormholeSpend _spend(
  String extrinsicId, {
  required int block,
  DateTime? at,
  required Map<String, int> outputs,
  int event = 0,
  String call = WormholeSpend.privateBatchCall,
  String? blockAuthor,
}) => WormholeSpend(
  extrinsicId: extrinsicId,
  blockHeight: block,
  timestamp: at ?? _t0,
  call: call,
  outputs: [
    for (final (i, e) in outputs.entries.indexed)
      WormholeOutput(id: _id(block, event + i), exitAccountId: e.key, amount: wormholeTokenFromScaled(e.value)),
  ],
  blockAuthor: blockAuthor,
);

List<TransactionEvent> _history(List<WormholeUtxo> received, Map<String, WormholeSpend> spends) => buildWormholeHistory(
  accountId: _account,
  ownAddresses: {_account, _external1, _change0},
  received: received,
  spends: spends,
);

BigInt _scaled(int scaled) => wormholeTokenFromScaled(scaled);

Iterable<WormholeTransferEvent> _sends(List<TransactionEvent> history) =>
    history.whereType<WormholeTransferEvent>().where((e) => e.from == _account);

void main() {
  test('incoming transfers become received rows, newest first', () {
    final history = _history([
      _received('n1', scaled: 100, block: 1),
      _received('n2', to: _external1, scaled: 200, block: 2, at: _t0.add(const Duration(hours: 1))),
    ], {});

    expect(history.map((e) => e.id), [_id(2, 0), _id(1, 0)]);
    for (final event in history) {
      expect(event, isA<TransferEvent>().having((e) => e.fee, 'fee', BigInt.zero));
      expect(event, isNot(isA<WormholeTransferEvent>()));
      expect(event.from, _bob);
      expect(event.to, _account);
    }
    expect(history.first.amount, _scaled(200));
  });

  test('a send with change shows the recipient, the amount and the fee, and hides the change', () {
    final history = _history(
      [
        _received('n1', scaled: 1000),
        _received('c1', to: _change0, scaled: 399, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
      ],
      {
        'n1': _spend('0xs1', block: 5, outputs: {_alice: 600, _change0: 399}),
      },
    );

    expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0)]));
    final sent = _sends(history).single;
    expect(sent.to, _alice);
    expect(sent.amount, _scaled(600));
    expect(sent.fee, _scaled(1));
    expect(sent.extrinsicHash, '0xs1');
    expect(sent.blockNumber, 5);
  });

  test('a send without change spends its inputs entirely', () {
    final history = _history(
      [_received('n1', scaled: 1000)],
      {
        'n1': _spend('0xs1', block: 5, outputs: {_alice: 999}),
      },
    );

    final sent = _sends(history).single;
    expect(sent.amount, _scaled(999));
    expect(sent.fee, _scaled(1));
  });

  test('change returned to an external-branch address is hidden too', () {
    final history = _history(
      [
        _received('n1', scaled: 1000),
        _received('c1', to: _external1, scaled: 399, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
      ],
      {
        'n1': _spend('0xs1', block: 5, outputs: {_alice: 600, _external1: 399}),
      },
    );

    expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0)]));
    expect(_sends(history).single.amount, _scaled(600));
  });

  group("the block author's share of the volume fee", () {
    // 50.00 in: the fee is 0.02, half burned and half minted to the miner,
    // which the indexer lists as a third exit of the proof.
    const inputs = 5000;

    test('is neither the recipient nor change, and stays inside the fee', () {
      final history = _history(
        [
          _received('n1', scaled: inputs),
          _received('c1', to: _change0, scaled: 998, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
        ],
        {
          'n1': _spend('0xs1', block: 5, blockAuthor: _miner, outputs: {_alice: 4000, _change0: 998, _miner: 1}),
        },
      );

      // The change is hidden rather than listed as a receipt.
      expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0)]));
      final sent = _sends(history).single;
      expect(sent.to, _alice);
      expect(sent.amount, _scaled(4000));
      expect(sent.fee, _scaled(2));
      expect(sent.batches.single.changeToken, _scaled(998));
    });

    test('is the exit the runtime computes from the other exits, as seen on chain', () {
      // Two mainnet proofs: exits of 36.61 and 79.85 earned their miners 0.01
      // and 0.02; exits of 9.98 earn nothing (fee 0.01, all of it burned).
      WormholeOutput? share(Map<String, int> outputs) =>
          feeShareOf(_spend('0xs1', block: 5, blockAuthor: _miner, outputs: outputs));

      expect(share({_alice: 3598, _bob: 63, _miner: 1})?.amount, _scaled(1));
      expect(share({_alice: 7900, _bob: 85, _miner: 2})?.amount, _scaled(2));
      expect(share({_alice: 7900, _bob: 85, _miner: 1}), isNull);
      expect(share({_miner: 1, _change0: 998}), isNull);
    });

    test('a payment to the block author is a payment, large or small', () {
      final large = _sends(
        _history(
          [_received('n1', scaled: inputs)],
          {
            'n1': _spend('0xs1', block: 5, blockAuthor: _miner, outputs: {_miner: 4998}),
          },
        ),
      ).single;
      expect(large.to, _miner);
      expect(large.amount, _scaled(4998));

      // 10.00 in, 0.01 to the author, 9.98 change: the fee is 0.01 and the
      // author's share of it rounds to nothing, so the 0.01 is the payment.
      final history = _history(
        [
          _received('n1', scaled: 1000),
          _received('c1', to: _change0, scaled: 998, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
        ],
        {
          'n1': _spend('0xs1', block: 5, blockAuthor: _miner, outputs: {_miner: 1, _change0: 998}),
        },
      );
      expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0)]));
      final small = _sends(history).single;
      expect(small.to, _miner);
      expect(small.amount, _scaled(1));
      expect(small.fee, _scaled(1));
    });

    test('a small payment next to the fee share is still the payment', () {
      final toAlice = _sends(
        _history(
          [_received('n1', scaled: inputs)],
          {
            'n1': _spend('0xs1', block: 5, blockAuthor: _miner, outputs: {_alice: 1, _change0: 4997, _miner: 1}),
          },
        ),
      ).single;
      expect(toAlice.to, _alice);
      expect(toAlice.amount, _scaled(1));
      expect(toAlice.fee, _scaled(2));

      // Both to the author and equal: the share is the leaf minted last.
      final toMiner = _sends(
        _history(
          [_received('n1', scaled: inputs)],
          {
            'n1': WormholeSpend(
              extrinsicId: '0xs1',
              blockHeight: 5,
              timestamp: _t0,
              call: WormholeSpend.privateBatchCall,
              blockAuthor: _miner,
              outputs: [
                WormholeOutput(id: _id(5, 0), exitAccountId: _miner, amount: _scaled(1)),
                WormholeOutput(id: _id(5, 1), exitAccountId: _change0, amount: _scaled(4997)),
                WormholeOutput(id: _id(5, 2), exitAccountId: _miner, amount: _scaled(1)),
              ],
            ),
          },
        ),
      ).single;
      expect(toMiner.to, _miner);
      expect(toMiner.amount, _scaled(1));
      expect(toMiner.fee, _scaled(2));
    });

    test('paid to this wallet, because it mined the block, is a receipt beside the hidden change', () {
      final received = [
        _received('n1', scaled: inputs),
        _received('c1', to: _change0, scaled: 998, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
        _received('r1', to: _external1, scaled: 1, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 2),
      ];
      final spends = {
        'n1': _spend('0xs1', block: 5, blockAuthor: _external1, outputs: {_alice: 4000, _change0: 998, _external1: 1}),
      };
      final history = _history(received, spends);

      expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0), _id(5, 2)]));
      final sent = _sends(history).single;
      expect(sent.to, _alice);
      expect(sent.amount, _scaled(4000));
      expect(sent.fee, _scaled(2));
      expect(sent.batches.single.changeToken, _scaled(998));
      final reward = history.singleWhere((e) => e.id == _id(5, 2));
      expect(reward, isA<WormholeTransferEvent>());
      expect(reward.amount, _scaled(1));

      final incoming = history.where((e) => e.from != _account).fold(BigInt.zero, (sum, e) => sum + e.amount);
      final outgoing = _sends(history).fold(BigInt.zero, (sum, e) => sum + e.amount + e.fee);
      final unspent = WormholeUtxoResult(received: received, spends: spends).utxos;
      expect(incoming - outgoing, unspent.fold(BigInt.zero, (sum, u) => sum + u.amount));
      expect(incoming - outgoing, _scaled(999));
    });

    test('cannot be told apart in a spend cached before block authors were recorded', () {
      final row = _sends(
        _history(
          [_received('n1', scaled: inputs)],
          {
            'n1': _spend('0xs1', block: 5, outputs: {_alice: 4000, _change0: 998, _miner: 1}),
          },
        ),
      ).single;

      expect(row.recipientUnknown, isTrue);
    });
  });

  test('a third-party payment into a change address is incoming', () {
    final history = _history([_received('n1', to: _change0, scaled: 50, extrinsicId: '0xother')], {});

    expect(history.single.id, _id(1, 0));
    expect(history.single.to, _account);
  });

  group('batches of one send merge into one row', () {
    test('carrying the last batch, with the change hidden', () {
      final last = _spend(
        '0xs2',
        block: 11,
        at: _t0.add(const Duration(minutes: 2)),
        outputs: {_alice: 300, _change0: 50},
      );
      final history = _history(
        [
          _received('n1', scaled: 701, event: 0),
          _received('n2', scaled: 351, event: 1),
          _received('c1', to: _change0, scaled: 50, viaWormhole: true, extrinsicId: '0xs2', block: 11, event: 1),
        ],
        {
          'n1': _spend('0xs1', block: 10, outputs: {_alice: 700}),
          'n2': last,
        },
      );

      final sent = _sends(history).single;
      expect(sent.amount, _scaled(1000));
      expect(sent.fee, _scaled(2));
      expect(sent.extrinsicHash, '0xs2');
      expect(sent.timestamp, last.timestamp);
      expect(sent.blockNumber, 11);
      expect(history.map((e) => e.id), unorderedEquals(['0xs2', _id(1, 0), _id(1, 1)]));
      // Every batch stays inspectable: its extrinsic, the inputs it consumed
      // and how it split them.
      expect(sent.batches.map((b) => b.extrinsicId), ['0xs1', '0xs2']);
      expect(sent.batches.map((b) => b.inputs.single.nullifierHex), ['n1', 'n2']);
      expect(sent.batches.map((b) => b.sentToken), [_scaled(700), _scaled(300)]);
      expect(sent.batches.last.changeToken, _scaled(50));
      expect(sent.batches.map((b) => b.feeToken), [_scaled(1), _scaled(1)]);
    });

    test('landing in one block, in event order whatever their hashes', () {
      final history = _history(
        [_received('n1', scaled: 701, event: 0), _received('n2', scaled: 351, event: 1)],
        {
          'n1': _spend('0xff', block: 10, event: 2, outputs: {_alice: 700}),
          'n2': _spend('0x00', block: 10, event: 7, outputs: {_alice: 300, _change0: 50}),
        },
      );

      final sent = _sends(history).single;
      expect(sent.amount, _scaled(1000));
      expect(sent.extrinsicHash, '0x00');
    });

    test('not when the later batch spends funds received after the earlier one', () {
      // A send without change spent everything, so a second send to the same
      // recipient can only use funds that arrived later.
      final history = _history(
        [_received('n1', scaled: 701, block: 1), _received('n2', scaled: 351, block: 15)],
        {
          'n1': _spend('0xs1', block: 10, outputs: {_alice: 700}),
          'n2': _spend('0xs2', block: 20, at: _t0.add(const Duration(minutes: 1)), outputs: {_alice: 350}),
        },
      );

      expect(_sends(history).map((e) => e.id), ['0xs2', '0xs1']);
    });

    test('not when further apart than the merge window, even from old funds', () {
      // A miner's equal leaves let an amount consume whole batches exactly, so
      // repeated sends to one recipient can all be change-free.
      final history = _history(
        [_received('n1', scaled: 701, event: 0), _received('n2', scaled: 351, event: 1)],
        {
          'n1': _spend('0xs1', block: 10, at: _t0, outputs: {_alice: 700}),
          'n2': _spend(
            '0xs2',
            block: 500,
            at: _t0.add(wormholeSendMergeWindow + const Duration(seconds: 1)),
            outputs: {_alice: 350},
          ),
        },
      );

      expect(_sends(history).map((e) => e.id), ['0xs2', '0xs1']);
    });

    test('not after a batch that returned change', () {
      final history = _history(
        [_received('n1', scaled: 701, event: 0), _received('n2', scaled: 351, event: 1)],
        {
          'n1': _spend('0xs1', block: 10, outputs: {_alice: 600, _change0: 100}),
          'n2': _spend('0xs2', block: 11, outputs: {_alice: 350}),
        },
      );

      expect(_sends(history).map((e) => e.amount), [_scaled(350), _scaled(600)]);
    });

    test('not across recipients', () {
      final history = _history(
        [_received('n1', scaled: 701, event: 0), _received('n2', scaled: 351, event: 1)],
        {
          'n1': _spend('0xs1', block: 10, outputs: {_alice: 700}),
          'n2': _spend('0xs2', block: 11, outputs: {_bob: 350}),
        },
      );

      expect(_sends(history).map((e) => e.to), [_bob, _alice]);
    });
  });

  test('a receipt from another encrypted send is a wormhole event; a mining reward is not', () {
    final history = _history([
      _received('m1', scaled: 100, extrinsicId: '', block: 1),
      _received('w2', scaled: 100, viaWormhole: true, extrinsicId: '0xw', block: 2),
    ], {});

    final [receipt, reward] = history;
    expect(receipt, isA<WormholeTransferEvent>().having((e) => e.extrinsicHash, 'extrinsicHash', '0xw'));
    expect(reward, isNot(isA<WormholeTransferEvent>()));
    expect(reward.extrinsicHash, isNull);
  });

  test('rows reconcile with the unspent balance', () {
    final received = [
      _received('n1', scaled: 701, event: 0),
      _received('n2', scaled: 351, event: 1),
      _received('n3', scaled: 500, event: 2),
      _received('c1', to: _change0, scaled: 50, viaWormhole: true, extrinsicId: '0xs2', block: 11, event: 1),
    ];
    final spends = {
      'n1': _spend('0xs1', block: 10, outputs: {_alice: 700}),
      'n2': _spend('0xs2', block: 11, outputs: {_alice: 300, _change0: 50}),
    };
    final history = _history(received, spends);

    final incoming = history.where((e) => e.from != _account).fold(BigInt.zero, (sum, e) => sum + e.amount);
    final outgoing = _sends(history).fold(BigInt.zero, (sum, e) => sum + e.amount + e.fee);
    final unspent = WormholeUtxoResult(received: received, spends: spends).utxos;
    expect(incoming - outgoing, unspent.fold(BigInt.zero, (sum, u) => sum + u.amount));
  });

  group('a spend that is not one of this wallet\'s sends is reported by its inputs, without a recipient', () {
    WormholeTransferEvent sent(Map<String, int> outputs, {int inputs = 1000}) =>
        _sends(_history([_received('n1', scaled: inputs)], {'n1': _spend('0xs1', block: 5, outputs: outputs)})).single;

    test('bundled with another user\'s exit', () {
      final row = sent({_alice: 600, _bob: 100});
      expect(row.recipientUnknown, isTrue);
      expect(row.amount, _scaled(1000));
      expect(row.fee, BigInt.zero);
    });

    test('exiting more than its inputs', () {
      final row = sent({_alice: 600}, inputs: 100);
      expect(row.recipientUnknown, isTrue);
      expect(row.amount, _scaled(100));
    });

    test('paying only itself', () {
      final row = sent({_change0: 99}, inputs: 100);
      expect(row.recipientUnknown, isTrue);
      expect(row.amount, _scaled(100));
    });

    test('a public batch, even when its exits look like one of our sends', () {
      // Our 1000 in, 600 to alice, 399 change — and another client's segment
      // pays 1 unit into our address. Outputs alone would pass as our send.
      final history = _history(
        [
          _received('n1', scaled: 1000),
          _received('c1', to: _change0, scaled: 399, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
          _received('p1', to: _external1, scaled: 1, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 2),
        ],
        {
          'n1': _spend(
            '0xs1',
            block: 5,
            call: 'verify_public_batch',
            outputs: {_alice: 600, _change0: 399, _external1: 1},
          ),
        },
      );

      expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0), _id(5, 1), _id(5, 2)]));
      final row = _sends(history).single;
      expect(row.recipientUnknown, isTrue);
      expect(row.amount, _scaled(1000));
    });

    test('the private batch under its pre-rename call name is our send too', () {
      final history = _history(
        [
          _received('n1', scaled: 1000),
          _received('c1', to: _change0, scaled: 399, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
        ],
        {
          'n1': _spend('0xs1', block: 5, call: 'verify_aggregated_proof', outputs: {_alice: 600, _change0: 399}),
        },
      );

      expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0)]));
      expect(_sends(history).single.to, _alice);
    });

    test('a proof of only our inputs is our send, whatever it splits change into', () {
      final history = _history(
        [
          _received('n1', scaled: 1000),
          _received('c1', to: _change0, scaled: 399, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 1),
          _received('c2', to: _external1, scaled: 1, viaWormhole: true, extrinsicId: '0xs1', block: 5, event: 2),
        ],
        {
          'n1': _spend('0xs1', block: 5, outputs: {_alice: 600, _change0: 399, _external1: 1}),
        },
      );

      expect(history.map((e) => e.id), unorderedEquals(['0xs1', _id(1, 0)]));
      final sent = _sends(history).single;
      expect(sent.to, _alice);
      expect(sent.fee, BigInt.zero);
    });

    test('never merges with a neighbouring send', () {
      final history = _history(
        [_received('n1', scaled: 1000, event: 0), _received('n2', scaled: 500, event: 1)],
        {
          'n1': _spend('0xs1', block: 5, outputs: {_alice: 600, _bob: 100}),
          'n2': _spend('0xs2', block: 6, outputs: {_alice: 499}),
        },
      );

      expect(_sends(history).map((e) => e.recipientUnknown), [false, true]);
    });
  });

  test('a receipt reads back from its JSON as a wormhole event; a send does not serialise', () {
    final receipt = _history([_received('w1', scaled: 100, viaWormhole: true, extrinsicId: '0xw')], {}).single;
    final restored = WormholeTransferEvent.fromJson((receipt as WormholeTransferEvent).toJson());
    expect(restored, isA<WormholeTransferEvent>().having((e) => e.extrinsicHash, 'extrinsicHash', '0xw'));

    final send = _sends(
      _history(
        [_received('n1', scaled: 1000)],
        {
          'n1': _spend('0xs1', block: 5, outputs: {_alice: 999}),
        },
      ),
    ).single;
    expect(send.toJson, throwsStateError);
  });
}
