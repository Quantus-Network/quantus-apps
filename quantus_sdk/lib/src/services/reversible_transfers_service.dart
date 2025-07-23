import 'dart:async';

import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/resonance/resonance.dart';
import 'package:quantus_sdk/generated/resonance/types/pallet_reversible_transfers/high_security_account_data.dart';
import 'package:quantus_sdk/generated/resonance/types/pallet_reversible_transfers/pending_transfer.dart';
import 'package:quantus_sdk/generated/resonance/types/primitive_types/h256.dart';
import 'package:quantus_sdk/generated/resonance/types/qp_scheduler/block_number_or_timestamp.dart';
import 'package:quantus_sdk/generated/resonance/types/sp_core/crypto/account_id32.dart';
import 'package:quantus_sdk/generated/resonance/types/sp_runtime/multiaddress/multi_address.dart'
    as multi_address;
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

import 'substrate_service.dart';

/// Service for managing reversible transfers for theft deterrence and ad hoc transfers
class ReversibleTransfersService {
  static final ReversibleTransfersService _instance =
      ReversibleTransfersService._internal();
  factory ReversibleTransfersService() => _instance;
  ReversibleTransfersService._internal();

  final SubstrateService _substrateService = SubstrateService();

  /// Enable reversibility for the calling account with specified delay and policy
  /// Used for theft deterrence - enables all future transfers to be reversible
  Future<StreamSubscription<ExtrinsicStatus>> setHighSecurity({
    required Account account,
    required BlockNumberOrTimestamp delay,
    String? reverserAddress,
  }) async {
    print('Not implemented - add reverser to params');
    try {
      final resonanceApi = Resonance(_substrateService.provider!);

      // Convert reverser address if provided
      AccountId32? reverser;
      if (reverserAddress != null) {
        reverser = crypto.ss58ToAccountId(s: reverserAddress);
      }

      // Create the call
      final call = resonanceApi.tx.reversibleTransfers.setHighSecurity(
        delay: delay,
        interceptor: reverser ?? crypto.ss58ToAccountId(s: account.accountId),
        recoverer: reverser ?? crypto.ss58ToAccountId(s: account.accountId),
      );

      // Submit the transaction using substrate service
      return _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to enable reversibility: $e');
    }
  }

  /// Schedule a reversible transfer using account's default settings
  Future<StreamSubscription<ExtrinsicStatus>> scheduleReversibleTransfer({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final multiDest = const multi_address.$MultiAddress().id(
        crypto.ss58ToAccountId(s: recipientAddress),
      );

      // Create the call
      final call = resonanceApi.tx.reversibleTransfers.scheduleTransfer(
        dest: multiDest,
        amount: amount,
      );

      // Submit the transaction using substrate service
      return _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to schedule reversible transfer: $e');
    }
  }

  /// Schedule a reversible transfer with custom delay (ad hoc transfer)
  Future<StreamSubscription<ExtrinsicStatus>>
  scheduleReversibleTransferWithDelay({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required BlockNumberOrTimestamp delay,
    void Function(ExtrinsicStatus)? onStatus,
  }) {
    final resonanceApi = Resonance(_substrateService.provider!);
    final multiDest = const multi_address.$MultiAddress().id(
      crypto.ss58ToAccountId(s: recipientAddress),
    );

    final call = resonanceApi.tx.reversibleTransfers.scheduleTransferWithDelay(
      dest: multiDest,
      amount: amount,
      delay: delay,
    );

    // Submit the transaction using substrate service
    return _substrateService.submitExtrinsic(account, call, onStatus: onStatus);
  }

  /// Schedule a reversible transfer with custom delay in seconds
  Future<StreamSubscription<ExtrinsicStatus>>
  scheduleReversibleTransferWithDelaySeconds({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
    void Function(ExtrinsicStatus)? onStatus,
  }) {
    // convert seconds to milliseconds for runtime
    final delay = Timestamp(BigInt.from(delaySeconds) * BigInt.from(1000));
    return scheduleReversibleTransferWithDelay(
      account: account,
      recipientAddress: recipientAddress,
      amount: amount,
      delay: delay,
      onStatus: onStatus,
    );
  }

  /// Cancel a pending reversible transaction (theft deterrence - reverse a transaction)
  Future<StreamSubscription<ExtrinsicStatus>> cancelReversibleTransfer({
    required Account account,
    required H256 transactionId,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);

      // Create the call
      final call = resonanceApi.tx.reversibleTransfers.cancel(
        txId: transactionId,
      );

      // Submit the transaction using substrate service
      return _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to cancel reversible transfer: $e');
    }
  }

  /// Execute a scheduled transfer (typically called by the scheduler)
  Future<StreamSubscription<ExtrinsicStatus>> executeTransfer({
    required Account account,
    required H256 transactionId,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);

      // Create the call
      final call = resonanceApi.tx.reversibleTransfers.executeTransfer(
        txId: transactionId,
      );

      // Submit the transaction using substrate service
      return _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to execute transfer: $e');
    }
  }

  /// Query account's reversibility configuration
  Future<HighSecurityAccountData?> getAccountReversibilityConfig(
    String address,
  ) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final accountId = crypto.ss58ToAccountId(s: address);

      return await resonanceApi.query.reversibleTransfers.highSecurityAccounts(
        accountId,
      );
    } catch (e) {
      throw Exception('Failed to get account reversibility config: $e');
    }
  }

  /// Query pending transfer details
  Future<PendingTransfer?> getPendingTransfer(H256 transactionId) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);

      return await resonanceApi.query.reversibleTransfers.pendingTransfers(
        transactionId,
      );
    } catch (e) {
      throw Exception('Failed to get pending transfer: $e');
    }
  }

  /// Get account's pending transaction index
  Future<int> getAccountPendingIndex(String address) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final accountId = crypto.ss58ToAccountId(s: address);

      return await resonanceApi.query.reversibleTransfers.accountPendingIndex(
        accountId,
      );
    } catch (e) {
      throw Exception('Failed to get account pending index: $e');
    }
  }

  /// Check if account has reversibility enabled
  Future<bool> isReversibilityEnabled(String address) async {
    try {
      final config = await getAccountReversibilityConfig(address);
      return config != null;
    } catch (e) {
      throw Exception('Failed to check reversibility status: $e');
    }
  }

  /// Get all pending transfers for an account by querying storage
  Future<List<PendingTransfer>> getAccountPendingTransfers(
    String address,
  ) async {
    try {
      // Get the pending index to know how many transfers to check
      final pendingIndex = await getAccountPendingIndex(address);

      final pendingTransfers = <PendingTransfer>[];

      // Query each potential pending transfer
      // Note: This is a simplified approach - in practice you might want to
      // use storage iteration or events to get all pending transfers
      for (int i = 0; i < pendingIndex; i++) {
        // This would need the actual transaction ID generation logic
        // For now, this is a placeholder showing the pattern
      }

      return pendingTransfers;
    } catch (e) {
      throw Exception('Failed to get account pending transfers: $e');
    }
  }

  /// Helper method to create delay from milliseconds
  static BlockNumberOrTimestamp delayFromMilliseconds(int milliseconds) {
    return Timestamp(BigInt.from(milliseconds));
  }

  /// Helper method to create delay from block number
  static BlockNumberOrTimestamp delayFromBlocks(int blocks) {
    return BlockNumber(blocks);
  }

  /// Get constants related to reversible transfers
  Future<Map<String, dynamic>> getConstants() async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final constants = resonanceApi.constant.reversibleTransfers;

      return {
        'maxPendingPerAccount': constants.maxPendingPerAccount,
        'defaultDelay': constants.defaultDelay,
        'minDelayPeriodBlocks': constants.minDelayPeriodBlocks,
        'minDelayPeriodMoment': constants.minDelayPeriodMoment,
      };
    } catch (e) {
      throw Exception('Failed to get reversible transfers constants: $e');
    }
  }
}
