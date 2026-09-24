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
final _t0 = DateTime.utc(2026, 9, 1, 12);

WormholeUtxo _received(
  String id, {
  String to = _account,
  required int scaled,
  String from = _bob,
  String extrinsicId = '0xpay',
  int block = 1,
  DateTime? at,
}) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: id,
    blockHeight: block,
    timestamp: at ?? _t0,
    fromId: from,
    toId: to,
    amount: wormholeTokenFromScaled(scaled),
    toHash: '',
    leafIndex: BigInt.zero,
    transferCount: BigInt.zero,
    extrinsicId: extrinsicId,
  ),
  owner: WormholeAddressInfo(index: 0, address: to, secretHex: ''),
  nullifierHex: 'n$id',
);

/// A proof extrinsic exiting [outputs] (address → scaled amount), with exit
/// ids in the indexer's `<block>-<hash>-<event index>` form starting at [event].
WormholeSpend _spend(
  String extrinsicId, {
  required int block,
  DateTime? at,
  required Map<String, int> outputs,
  int event = 0,
}) => WormholeSpend(
  extrinsicId: extrinsicId,
  blockHeight: block,
  timestamp: at ?? _t0,
  outputs: [
    for (final (i, e) in outputs.entries.indexed)
      WormholeOutput(
        id: '${block.toString().padLeft(10, '0')}-00000-${(event + i).toString().padLeft(6, '0')}',
        exitAccountId: e.key,
        amount: wormholeTokenFromScaled(e.value),
      ),
  ],
);

List<TransactionEvent> _history(List<WormholeUtxo> received, Map<String, WormholeSpend> spends) => buildWormholeHistory(
  accountId: _account,
  ownAddresses: {_account, _external1, _change0},
  received: received,
  spends: spends,
);

BigInt _scaled(int scaled) => wormholeTokenFromScaled(scaled);

void main() {
  test('incoming transfers become received rows, newest first', () {
    final history = _history([
      _received('r1', scaled: 100, at: _t0),
      _received('r2', to: _external1, scaled: 200, at: _t0.add(const Duration(hours: 1))),
    ], {});

    expect(history.map((e) => e.id), ['r2', 'r1']);
    for (final event in history) {
      expect(event, isA<TransferEvent>().having((e) => e.fee, 'fee', BigInt.zero));
      expect(event, isNot(isA<WormholeTransferEvent>()));
      expect(event.from, _bob);
      expect(event.to, _account);
    }
    expect(history.first.amount, _scaled(200));
  });

  test('a send with change shows the recipient, the amount and the fee, and hides the change', () {
    final spend = _spend('0xs1', block: 5, outputs: {_alice: 600, _change0: 399});
    final history = _history(
      [
        _received('r1', scaled: 1000),
        _received('c1', to: _change0, scaled: 399, from: wormholeMintingAddress, extrinsicId: '0xs1', block: 5),
      ],
      {'nr1': spend},
    );

    expect(history.map((e) => e.id), unorderedEquals(['0xs1', 'r1']));
    final sent = history.whereType<WormholeTransferEvent>().single;
    expect(sent.from, _account);
    expect(sent.to, _alice);
    expect(sent.amount, _scaled(600));
    expect(sent.fee, _scaled(1));
    expect(sent.extrinsicHash, '0xs1');
    expect(sent.blockNumber, 5);
  });

  test('a send without change spends its inputs entirely', () {
    final history = _history(
      [_received('r1', scaled: 1000)],
      {
        'nr1': _spend('0xs1', block: 5, outputs: {_alice: 999}),
      },
    );

    final sent = history.whereType<WormholeTransferEvent>().single;
    expect(sent.amount, _scaled(999));
    expect(sent.fee, _scaled(1));
  });

  test('change returned to an external-branch address is hidden too', () {
    final history = _history(
      [
        _received('r1', scaled: 1000),
        _received('c1', to: _external1, scaled: 399, from: wormholeMintingAddress, extrinsicId: '0xs1'),
      ],
      {
        'nr1': _spend('0xs1', block: 5, outputs: {_alice: 600, _external1: 399}),
      },
    );

    expect(history.map((e) => e.id), unorderedEquals(['0xs1', 'r1']));
    expect(history.whereType<WormholeTransferEvent>().single.amount, _scaled(600));
  });

  test('a third-party payment into a change address is incoming', () {
    final history = _history([_received('r1', to: _change0, scaled: 50, extrinsicId: '0xother')], {});

    expect(history.single.id, 'r1');
    expect(history.single.to, _account);
  });

  test('each extrinsic of a multi-batch send is its own row, newest first, with its change hidden', () {
    final history = _history(
      [
        _received('r1', scaled: 701),
        _received('r2', scaled: 351),
        _received('c1', to: _change0, scaled: 50, from: wormholeMintingAddress, extrinsicId: '0xs2', block: 11),
      ],
      {
        'nr1': _spend('0xs1', block: 10, outputs: {_alice: 700}),
        'nr2': _spend('0xs2', block: 11, outputs: {_alice: 300, _change0: 50}),
      },
    );

    final sent = history.whereType<WormholeTransferEvent>().toList();
    expect(sent.map((e) => e.extrinsicHash), ['0xs2', '0xs1']);
    expect(sent.map((e) => e.amount), [_scaled(300), _scaled(700)]);
    expect(sent.map((e) => e.fee), [_scaled(1), _scaled(1)]);
    expect(history.map((e) => e.id), isNot(contains('c1')));
  });

  test('rows in one block follow event order, whatever their hashes', () {
    final history = _history(
      [_received('r1', scaled: 701), _received('r2', scaled: 351)],
      {
        'nr1': _spend('0xff', block: 10, event: 2, outputs: {_alice: 700}),
        'nr2': _spend('0x00', block: 10, event: 7, outputs: {_alice: 350}),
      },
    );

    expect(history.whereType<WormholeTransferEvent>().map((e) => e.id), ['0x00', '0xff']);
  });

  test('a receipt from another encrypted send is a wormhole event; a mining reward is not', () {
    final history = _history([
      _received('m1', scaled: 100, from: wormholeMintingAddress, extrinsicId: '', at: _t0),
      _received(
        'w2',
        scaled: 100,
        from: wormholeMintingAddress,
        extrinsicId: '0xw',
        at: _t0.add(const Duration(hours: 1)),
      ),
    ], {});

    final [receipt, reward] = history;
    expect(receipt, isA<WormholeTransferEvent>().having((e) => e.extrinsicHash, 'extrinsicHash', '0xw'));
    expect(reward, isNot(isA<WormholeTransferEvent>()));
    expect(reward.extrinsicHash, isNull);
  });

  test('rows reconcile with the unspent balance', () {
    final received = [
      _received('r1', scaled: 701),
      _received('r2', scaled: 351),
      _received('r3', scaled: 500),
      _received('c1', to: _change0, scaled: 50, from: wormholeMintingAddress, extrinsicId: '0xs2'),
    ];
    final spends = {
      'nr1': _spend('0xs1', block: 10, at: _t0, outputs: {_alice: 700}),
      'nr2': _spend('0xs2', block: 11, at: _t0.add(const Duration(minutes: 2)), outputs: {_alice: 300, _change0: 50}),
    };
    final history = _history(received, spends);

    final incoming = history.where((e) => e.from != _account).fold(BigInt.zero, (sum, e) => sum + e.amount);
    final outgoing = history
        .where((e) => e.from == _account)
        .fold(BigInt.zero, (sum, e) => sum + e.amount + (e as TransferEvent).fee);
    final unspent = WormholeUtxoResult(received: received, spends: spends).utxos;
    expect(incoming - outgoing, unspent.fold(BigInt.zero, (sum, u) => sum + u.amount));
  });

  group('a spend that is not one of this wallet\'s sends is reported by its inputs, without a recipient', () {
    WormholeTransferEvent sent(Map<String, int> outputs, {int inputs = 1000}) => _history(
      [_received('r1', scaled: inputs)],
      {'nr1': _spend('0xs1', block: 5, outputs: outputs)},
    ).whereType<WormholeTransferEvent>().single;

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

    test('keeps a payment to this wallet inside the proof as a receipt', () {
      final history = _history(
        [
          _received('r1', scaled: 1000),
          _received('p1', to: _external1, scaled: 100, from: wormholeMintingAddress, extrinsicId: '0xs1', block: 5),
        ],
        {
          'nr1': _spend('0xs1', block: 5, outputs: {_alice: 600, _bob: 100, _external1: 100}),
        },
      );

      final receipt = history.singleWhere((e) => e.id == 'p1');
      expect(receipt, isA<WormholeTransferEvent>().having((e) => e.to, 'to', _account));
      expect(history.whereType<WormholeTransferEvent>().singleWhere((e) => e.recipientUnknown).amount, _scaled(1000));
    });
  });
}
