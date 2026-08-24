import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

const _dest = 'dest';
const _siblingHeight = 1000;

String _siblingId(int index) => '0000001000-sib-${index.toString().padLeft(6, '0')}';

/// [transferPageSize] + 1 rows so a 3-wide same-height group sits on the OFFSET
/// boundary (unique-order positions 298, 299, 300).
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

bool _queryHasUniqueTransferOrder(String query) {
  final hasHeight = query.contains('block: {height: asc}');
  final hasTieBreak = query.contains('{id: asc}') || query.contains('{leaf_index: asc}');
  return hasHeight && hasTieBreak;
}

/// Hasura/Postgres LIMIT+OFFSET when `order_by` is not unique: each page
/// independently orders ties, so a sibling can be returned twice and another
/// omitted. Unique `{height, id}` partitions cleanly.
List<WormholeTransfer> _pageLikeHasura({
  required List<WormholeTransfer> rows,
  required String query,
  required int limit,
  required int offset,
  required int afterBlock,
}) {
  final filtered = rows.where((r) => r.blockHeight > afterBlock).toList();
  final unique = _queryHasUniqueTransferOrder(query);
  filtered.sort((a, b) {
    final byHeight = a.blockHeight.compareTo(b.blockHeight);
    if (byHeight != 0) return byHeight;
    if (unique) return a.id.compareTo(b.id);
    return offset == 0 ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
  });
  return filtered.skip(offset).take(limit).toList();
}

List<WormholeTransfer> _walkOfficialQuery(List<WormholeTransfer> rows) {
  final all = <WormholeTransfer>[];
  var offset = 0;
  while (true) {
    final page = _pageLikeHasura(
      rows: rows,
      query: WormholeUtxoService.transfersToAddressesQuery,
      limit: WormholeUtxoService.transferPageSize,
      offset: offset,
      afterBlock: 0,
    );
    all.addAll(page);
    if (page.length < WormholeUtxoService.transferPageSize) break;
    offset += WormholeUtxoService.transferPageSize;
  }
  return all;
}

void main() {
  test('OFFSET walk of the official transfer query keeps same-height siblings', () {
    final rows = _boundarySiblingTransfers();
    final siblingIds = [for (var i = 0; i < 3; i++) _siblingId(i)];
    final walked = _walkOfficialQuery(rows);
    final ids = walked.map((t) => t.id).toList();

    expect(ids.toSet(), hasLength(rows.length), reason: 'height-only OFFSET can drop a tied sibling');
    expect(ids, containsAll(siblingIds));
    expect(ids.toSet(), hasLength(ids.length), reason: 'pages must not overlap on a tied height');
  });

  test('transfer cache is versioned so a prior height-only miss is re-walked', () {
    expect(WormholeUtxoService.transferCacheVersion, 2);
  });
}
