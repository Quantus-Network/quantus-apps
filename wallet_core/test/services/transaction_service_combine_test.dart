import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/transaction_service.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  TransferEvent settled(String id, DateTime at) => TransferEvent(
    id: id,
    from: 'qzA',
    to: 'qzB',
    amount: BigInt.one,
    timestamp: at,
    fee: BigInt.one,
    blockNumber: 1,
    blockHash: '0xblock',
  );

  final older = settled('older', DateTime.utc(2026, 11, 18));
  final newer = settled('newer', DateTime.utc(2026, 11, 20));
  final failed = PendingTransactionEvent(
    tempId: 'failed',
    from: 'qzA',
    to: 'qzB',
    amount: BigInt.one,
    timestamp: DateTime.utc(2026, 11, 19),
    fee: BigInt.one,
    transactionState: TransactionState.failed,
  );
  final sending = PendingTransactionEvent(
    tempId: 'sending',
    from: 'qzA',
    to: 'qzB',
    amount: BigInt.one,
    timestamp: DateTime.utc(2026, 11, 20, 12),
    fee: BigInt.one,
  );

  List<TransactionEvent> combine({
    List<PendingTransactionEvent> pending = const [],
    List<PendingMultisigApprovalEvent> approvals = const [],
    required List<TransactionEvent> otherTransfers,
  }) => container
      .read(transactionServiceProvider)
      .combineAndDeduplicateTransactions(
        pendingCancellationIds: const {},
        pendingTransactions: pending,
        pendingMultisigCreations: const [],
        pendingMultisigProposals: const [],
        pendingMultisigApprovals: approvals,
        pendingMultisigExecutions: const [],
        pendingMultisigCancellations: const [],
        scheduledReversibleTransfers: const [],
        otherTransfers: otherTransfers,
      );

  test('leaves the settled transfers it is given as they were: a failed send is not added, nor are they reordered', () {
    // Oldest first, as no caller should find them rearranged.
    final given = <TransactionEvent>[older, newer];

    combine(pending: [failed], otherTransfers: given);

    expect(given, [older, newer]);
  });

  test('shows a send that failed among the settled ones, newest first, after what is still pending', () {
    final result = combine(pending: [sending, failed], otherTransfers: [older, newer]);

    expect(result.map((tx) => tx.id), ['sending', 'newer', 'failed', 'older']);
  });

  test('takes settled transfers in a list that cannot be changed', () {
    final result = combine(pending: [failed], otherTransfers: const []);

    expect(result.map((tx) => tx.id), ['failed']);
  });

  group('an approval on its way', () {
    PendingMultisigApprovalEvent approving({String? hash}) => PendingMultisigApprovalEvent(
      id: 'approving',
      multisigAddress: 'qzTeam',
      proposalId: 3,
      approverId: 'qzA',
      recipient: 'qzC',
      amount: BigInt.one,
      fee: BigInt.one,
      extrinsicHash: hash,
      submittedAt: DateTime.utc(2026, 11, 20, 13),
    );
    MultisigProposalApprovedEvent approved({String? hash, String id = 'approved'}) => MultisigProposalApprovedEvent(
      id: id,
      approverId: 'qzA',
      multisigAddress: 'qzTeam',
      recipient: 'qzC',
      amount: BigInt.one,
      proposalId: 3,
      approvalsCount: 2,
      timestamp: DateTime.utc(2026, 11, 20, 13, 1),
      blockNumber: 2,
      blockHash: '0xblock',
      extrinsicHash: hash,
    );

    test('is listed first, with what is settled after it', () {
      final result = combine(
        approvals: [approving(hash: '0xa')],
        otherTransfers: [older],
      );

      expect(result.map((tx) => tx.id), ['approving', 'older']);
    });

    test('gives way to the indexed approval sent in the same transaction: never two rows', () {
      final result = combine(
        approvals: [approving(hash: '0xa')],
        otherTransfers: [
          approved(hash: '0xa'),
          older,
        ],
      );

      expect(result.map((tx) => tx.id), ['approved', 'older']);
    });

    test("stays beside another approval's indexed row", () {
      final result = combine(
        approvals: [approving(hash: '0xa')],
        otherTransfers: [approved(hash: '0xb')],
      );

      expect(result.map((tx) => tx.id), ['approving', 'approved']);
    });
  });
}
