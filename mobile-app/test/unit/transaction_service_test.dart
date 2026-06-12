import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('TransactionService.deserializeTxEventFromJsonIfPossible', () {
    /// Typical REST shape (nested maps, amount/fee as decimal strings).
    Map<String, dynamic> transferPayloadFromSample() => {
      'amount': '1000000000',
      'sender': {'id': 'qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC'},
      'id': '0000197242-9c90c-000002',
      'receiver': {'id': 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda'},
      'block': {'hash': '0x9c90cf5b0d7348e49c7ed427b42f5cc7cfe37e11bd7f4e3254c7fc4c7acbbf62', 'height': 197242},
      'extrinsic': {'id': '0x60db7af926aa917d0e15c02fa4ddf54ed759ae564b380b8e73b63570000924e7'},
      'fee': '8189972000',
      'type': 'TRANSFER',
      'timestamp': '2026-05-12T12:39:51.706Z',
    };

    test('returns TransferEvent for TRANSFER type with sample payload', () {
      final service = container.read(transactionServiceProvider);
      final json = transferPayloadFromSample();

      final event = service.deserializeTxEventFromJsonIfPossible(json);

      expect(event, isA<TransferEvent>());
      final transfer = event! as TransferEvent;
      expect(transfer.id, '0000197242-9c90c-000002');
      expect(transfer.from, 'qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC');
      expect(transfer.to, 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda');
      expect(transfer.amount, BigInt.parse('1000000000'));
      expect(transfer.fee, BigInt.parse('8189972000'));
      expect(transfer.blockNumber, 197242);
      expect(transfer.blockHash, '0x9c90cf5b0d7348e49c7ed427b42f5cc7cfe37e11bd7f4e3254c7fc4c7acbbf62');
      expect(transfer.extrinsicHash, '0x60db7af926aa917d0e15c02fa4ddf54ed759ae564b380b8e73b63570000924e7');
      expect(transfer.timestamp.toUtc(), DateTime.parse('2026-05-12T12:39:51.706Z').toUtc());
    });

    test('returns null when type is not supported', () {
      final service = container.read(transactionServiceProvider);
      final json = <String, dynamic>{...transferPayloadFromSample(), 'type': 'UNKNOWN'};

      expect(service.deserializeTxEventFromJsonIfPossible(json), isNull);
    });

    test('parses FCM-style TRANSFER (JSON string block/senders, int amounts, '
        'top-level extrinsicHash)', () {
      final service = container.read(transactionServiceProvider);
      final json = <String, dynamic>{
        'amount': 1000000000,
        'fee': 8189972000,
        'sender': '{"id":"qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC"}',
        'id': '0000197378-4f5d2-000002',
        'receiver': '{"id":"qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda"}',
        'block': '{"hash":"0x4f5d27e7b1c679e64292606c9560432f610f7a6fccab992f5ab6326f5171f90c","height":197378}',
        'extrinsicHash': '0xc399a24c2cd9b3a85f2b10cdb6a0bb98ff8f02eb8185c23959f9b7e7d943a9b7',
        'type': 'TRANSFER',
        'timestamp': '2026-05-12T13:08:21.846Z',
      };

      final event = service.deserializeTxEventFromJsonIfPossible(json);

      expect(event, isA<TransferEvent>());
      final transfer = event! as TransferEvent;
      expect(transfer.blockNumber, 197378);
      expect(transfer.extrinsicHash, '0xc399a24c2cd9b3a85f2b10cdb6a0bb98ff8f02eb8185c23959f9b7e7d943a9b7');
    });
  });

  group('TransactionService.combineAndDeduplicateTransactions', () {
    PendingMultisigProposalEvent pendingProposal({
      String id = 'pending_proposal_1',
      String proposerId = 'proposer',
      String multisigAddress = 'multisig',
      String recipient = 'recipient',
      BigInt? amount,
    }) {
      final transferAmount = amount ?? BigInt.from(2000);
      return PendingMultisigProposalEvent(
        tempId: id,
        multisigAddress: multisigAddress,
        proposerId: proposerId,
        recipient: recipient,
        amount: transferAmount,
        deposit: BigInt.from(100),
        expiryBlock: 999,
        palletFee: BigInt.from(50),
      );
    }

    MultisigProposalCreatedEvent indexedProposal({
      String proposerId = 'proposer',
      String multisigAddress = 'multisig',
      String recipient = 'recipient',
      BigInt? amount,
      String? extrinsicHash,
    }) {
      final transferAmount = amount ?? BigInt.from(2000);
      return MultisigProposalCreatedEvent(
        id: 'ae-ms-proposal-created-1',
        proposerId: proposerId,
        multisigAddress: multisigAddress,
        recipient: recipient,
        amount: transferAmount,
        palletFee: BigInt.from(50),
        deposit: BigInt.from(100),
        fee: BigInt.from(5),
        timestamp: DateTime.utc(2026, 6, 3),
        blockNumber: 1,
        blockHash: '0xabc',
        extrinsicHash: extrinsicHash,
      );
    }

    test('includes pending proposal for proposer feed', () {
      final service = container.read(transactionServiceProvider);
      final pending = pendingProposal();

      final result = service.combineAndDeduplicateTransactions(
        pendingCancellationIds: {},
        pendingTransactions: [],
        pendingMultisigCreations: [],
        pendingMultisigProposals: [pending],
        pendingMultisigExecutions: [],
        pendingMultisigCancellations: [],
        scheduledReversibleTransfers: [],
        otherTransfers: [],
      );

      expect(result, hasLength(1));
      expect(result.first, same(pending));
    });

    test('replaces pending proposal with indexed event for same activity key', () {
      final service = container.read(transactionServiceProvider);
      const hash = '0xshared-hash';
      final pending = pendingProposal().copyWith(extrinsicHash: hash);
      final indexed = indexedProposal(extrinsicHash: hash);

      final result = service.combineAndDeduplicateTransactions(
        pendingCancellationIds: {},
        pendingTransactions: [],
        pendingMultisigCreations: [],
        pendingMultisigProposals: [pending],
        pendingMultisigExecutions: [],
        pendingMultisigCancellations: [],
        scheduledReversibleTransfers: [],
        otherTransfers: [indexed],
      );

      expect(result, hasLength(1));
      expect(result.first, isA<MultisigProposalCreatedEvent>());
    });

    test('replaces pending proposal when extrinsic hash matches indexed event', () {
      final service = container.read(transactionServiceProvider);
      const hash = '0xabc123';
      final pending = pendingProposal().copyWith(extrinsicHash: hash);
      final indexedWithHash = MultisigProposalCreatedEvent(
        id: 'ae-ms-proposal-created-2',
        proposerId: 'proposer',
        multisigAddress: 'multisig',
        recipient: 'other-recipient',
        amount: BigInt.from(9999),
        palletFee: BigInt.from(50),
        deposit: BigInt.from(100),
        fee: BigInt.from(5),
        timestamp: DateTime.utc(2026, 6, 4),
        blockNumber: 2,
        blockHash: '0xdef',
        extrinsicHash: hash,
      );

      final result = service.combineAndDeduplicateTransactions(
        pendingCancellationIds: {},
        pendingTransactions: [],
        pendingMultisigCreations: [],
        pendingMultisigProposals: [pending],
        pendingMultisigExecutions: [],
        pendingMultisigCancellations: [],
        scheduledReversibleTransfers: [],
        otherTransfers: [indexedWithHash],
      );

      expect(result, hasLength(1));
      expect(result.first, same(indexedWithHash));
    });

    PendingMultisigExecutionEvent pendingExecution({
      String id = 'pending_execution_1',
      String executorId = 'executor',
      String multisigAddress = 'multisig',
      String recipient = 'recipient',
      BigInt? amount,
      BigInt? fee,
      String? extrinsicHash,
    }) {
      return PendingMultisigExecutionEvent(
        tempId: id,
        multisigAddress: multisigAddress,
        proposalId: 5,
        executorId: executorId,
        recipient: recipient,
        amount: amount ?? BigInt.from(2000),
        fee: fee ?? BigInt.from(18),
        extrinsicHash: extrinsicHash,
      );
    }

    MultisigProposalExecutedEvent indexedExecution({
      String executorId = 'executor',
      String multisigAddress = 'multisig',
      String recipient = 'recipient',
      BigInt? amount,
      String? extrinsicHash,
    }) {
      return MultisigProposalExecutedEvent(
        id: 'ae-ms-exec-1',
        executorId: executorId,
        multisigAddress: multisigAddress,
        recipient: recipient,
        amount: amount ?? BigInt.from(2000),
        proposalId: 5,
        approvers: const ['signer1', 'signer2'],
        result: 'Ok',
        fee: BigInt.from(18),
        timestamp: DateTime.utc(2026, 6, 3),
        blockNumber: 1,
        blockHash: '0xabc',
        extrinsicHash: extrinsicHash,
      );
    }

    test('includes pending execution for executor feed', () {
      final service = container.read(transactionServiceProvider);
      final pending = pendingExecution();

      final result = service.combineAndDeduplicateTransactions(
        pendingCancellationIds: {},
        pendingTransactions: [],
        pendingMultisigCreations: [],
        pendingMultisigProposals: [],
        pendingMultisigExecutions: [pending],
        pendingMultisigCancellations: [],
        scheduledReversibleTransfers: [],
        otherTransfers: [],
      );

      expect(result, hasLength(1));
      expect(result.first, same(pending));
    });

    test('replaces pending execution with indexed event for same activity key', () {
      final service = container.read(transactionServiceProvider);
      const hash = '0xexec-hash';
      final pending = pendingExecution(extrinsicHash: hash);
      final indexed = indexedExecution(extrinsicHash: hash);

      final result = service.combineAndDeduplicateTransactions(
        pendingCancellationIds: {},
        pendingTransactions: [],
        pendingMultisigCreations: [],
        pendingMultisigProposals: [],
        pendingMultisigExecutions: [pending],
        pendingMultisigCancellations: [],
        scheduledReversibleTransfers: [],
        otherTransfers: [indexed],
      );

      expect(result, hasLength(1));
      expect(result.first, isA<MultisigProposalExecutedEvent>());
    });
  });
}
