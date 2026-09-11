import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

const _dest = 'dest';
const _siblingHeight = 1000;

String _siblingId(int index) => '0000001000-sib-${index.toString().padLeft(6, '0')}';

/// [WormholeUtxoService.transferPageSize] + 1 rows so a 3-wide same-height
/// group straddles the page boundary (positions 298, 299, 300 in
/// `(block_height, id)` order).
List<WormholeTransfer> _boundarySiblingTransfers() {
  final pageSize = WormholeUtxoService.transferPageSize;
  final total = pageSize + 1;
  final firstSibling = pageSize - 2;
  return [
    for (var i = 0; i < total; i++)
      WormholeTransfer(
        id: (i >= firstSibling && i <= firstSibling + 2)
            ? _siblingId(i - firstSibling)
            : 'h${(i < firstSibling ? i + 1 : _siblingHeight + 1 + (i - firstSibling - 3)).toString().padLeft(10, '0')}-synth-${i.toString().padLeft(6, '0')}',
        blockHeight: (i >= firstSibling && i <= firstSibling + 2)
            ? _siblingHeight
            : (i < firstSibling ? i + 1 : _siblingHeight + 1 + (i - firstSibling - 3)),
        fromId: 'from',
        toId: _dest,
        amount: BigInt.from(1000000000000),
        toHash: '',
        leafIndex: BigInt.from(i),
        transferCount: BigInt.from(i),
      ),
  ];
}

int _byHeightThenId(WormholeTransfer a, WormholeTransfer b) {
  final byHeight = a.blockHeight.compareTo(b.blockHeight);
  return byHeight != 0 ? byHeight : a.id.compareTo(b.id);
}

/// In-memory stand-in for Hasura evaluating the keyset query: rows to the
/// requested addresses above [afterBlock], strictly after the cursor in
/// `(block_height, id)` order, first [limit] of them.
class _KeysetIndexer extends WormholeUtxoService {
  _KeysetIndexer(this.rows);

  final List<WormholeTransfer> rows;
  final List<WormholeTransferCursor?> requestedCursors = [];

  @override
  Future<List<WormholeTransfer>> queryTransfersPage({
    required List<String> toAddresses,
    required int afterBlock,
    WormholeTransferCursor? after,
    int limit = WormholeUtxoService.transferPageSize,
  }) async {
    requestedCursors.add(after);
    final matching = rows.where((r) => toAddresses.contains(r.toId) && r.blockHeight > afterBlock).where((r) {
      if (after == null) return true;
      if (r.blockHeight != after.blockHeight) return r.blockHeight > after.blockHeight;
      return r.id.compareTo(after.id) > 0;
    }).toList()..sort(_byHeightThenId);
    return matching.take(limit).toList();
  }
}

void main() {
  group('transfersToAddresses queries', () {
    test('first page filters on indexed scalar columns and orders by (block_height, id)', () {
      const query = WormholeUtxoService.transfersToAddressesQuery;

      expect(query, contains(r'to_id: {_in: $tos}'));
      expect(query, contains(r'block_height: {_gt: $afterBlock}'));
      expect(query, contains('order_by: [{block_height: asc}, {id: asc}]'));
      expect(query, isNot(contains('offset')), reason: 'OFFSET re-scans every earlier row on each page');
      expect(query, isNot(contains('to: {')), reason: 'a nested relation filter cannot use (to_id, block_height, id)');
      expect(query, isNot(contains('block: {')), reason: 'block height is denormalized onto transfer');
    });

    test('next page continues strictly after the (block_height, id) cursor', () {
      const query = WormholeUtxoService.transfersToAddressesAfterQuery;

      expect(query, contains(r'block_height: {_gte: $cursorHeight}'));
      expect(query, contains(r'_not: {block_height: {_eq: $cursorHeight}, id: {_lte: $cursorId}}'));
      expect(query, contains('order_by: [{block_height: asc}, {id: asc}]'));
      expect(query, isNot(contains('offset')));
      expect(query, isNot(contains('_or')), reason: '_or keyset predicates plan as BitmapOr + sort');
    });
  });

  test('caches are generation-versioned so a network switch never reads the previous chain', () {
    expect(WormholeUtxoService.cacheVersion, 3);
  });
  
  test('keyset walk returns every row once, including same-height siblings on the page boundary', () async {
    final rows = _boundarySiblingTransfers();
    final indexer = _KeysetIndexer(rows);

    final walked = await indexer.fetchAllTransfers(toAddresses: const [_dest], afterBlock: 0);
    final ids = walked.map((t) => t.id).toList();

    expect(ids, hasLength(rows.length));
    expect(ids.toSet(), hasLength(rows.length), reason: 'no row may be returned twice');
    expect(ids, containsAll([for (var i = 0; i < 3; i++) _siblingId(i)]));

    final lastOfFirstPage = walked[WormholeUtxoService.transferPageSize - 1];
    expect(indexer.requestedCursors, hasLength(2));
    expect(indexer.requestedCursors[0], isNull, reason: 'first page has no cursor');
    expect(indexer.requestedCursors[1]?.blockHeight, lastOfFirstPage.blockHeight);
    expect(indexer.requestedCursors[1]?.id, lastOfFirstPage.id);
  });

  test('a short page ends the walk without another request', () async {
    final indexer = _KeysetIndexer(_boundarySiblingTransfers().take(5).toList());

    final walked = await indexer.fetchAllTransfers(toAddresses: const [_dest], afterBlock: 0);

    expect(walked, hasLength(5));
    expect(indexer.requestedCursors, hasLength(1));
  });
}
