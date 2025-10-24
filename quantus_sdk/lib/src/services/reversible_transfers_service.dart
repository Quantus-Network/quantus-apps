import 'dart:async';
import 'dart:typed_data';

import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/schrodinger/schrodinger.dart';
import 'package:quantus_sdk/generated/schrodinger/types/pallet_reversible_transfers/high_security_account_data.dart';
import 'package:quantus_sdk/generated/schrodinger/types/pallet_reversible_transfers/pending_transfer.dart';
import 'package:quantus_sdk/generated/schrodinger/types/primitive_types/h256.dart';
import 'package:quantus_sdk/generated/schrodinger/types/qp_scheduler/block_number_or_timestamp.dart'
    as qp;
import 'package:quantus_sdk/generated/schrodinger/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/generated/schrodinger/types/sp_runtime/multiaddress/multi_address.dart'
    as multi_address;
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/extrinsic_fee_data.dart';
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
  Future<Uint8List> setHighSecurity({
    required Account account,
    required Account guardian,
    required qp.BlockNumberOrTimestamp delay,
  }) async {
    print('Not implemented - add reverser to params');
    try {
      final resonanceApi = Schrodinger(_substrateService.provider!);

      // Create the call
      final call = resonanceApi.tx.reversibleTransfers.setHighSecurity(
        delay: delay,
        interceptor: crypto.ss58ToAccountId(s: guardian.accountId),
      );

      // Submit the transaction using substrate service
      return _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to enable reversibility: $e');
    }
  }

  /// Schedule a reversible transfer using account's default settings
  Future<Uint8List> scheduleReversibleTransfer({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
  }) async {
    try {
      final resonanceApi = Schrodinger(_substrateService.provider!);
      final multiDest = const multi_address.$MultiAddress().id(
        crypto.ss58ToAccountId(s: recipientAddress),
      );

      // Create the call
      final call = resonanceApi.tx.reversibleTransfers.scheduleTransfer(
        dest: multiDest,
        amount: amount,
      );
      call.hashCode;

      // Submit the transaction using substrate service
      return _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to schedule reversible transfer: $e');
    }
  }

  /// Schedule a reversible transfer with custom delay (ad hoc transfer)
  Future<Uint8List> scheduleReversibleTransferWithDelay({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required qp.BlockNumberOrTimestamp delay,
    void Function(ExtrinsicStatus)? onStatus,
  }) {
    ReversibleTransfers call = getReversibleTransferCall(
      recipientAddress,
      amount,
      delay,
    );

    // Submit the transaction using substrate service
    return _substrateService.submitExtrinsic(account, call);
  }

  Future<ExtrinsicFeeData> getReversibleTransferWithDelayFeeEstimate({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
  }) {
    final delay = qp.Timestamp(BigInt.from(delaySeconds) * BigInt.from(1000));
    ReversibleTransfers call = getReversibleTransferCall(
      recipientAddress,
      amount,
      delay,
    );

    // Submit the transaction using substrate service
    return _substrateService.getFeeForCall(account, call);
  }

  ReversibleTransfers getReversibleTransferCall(
    String recipientAddress,
    BigInt amount,
    qp.BlockNumberOrTimestamp delay,
  ) {
    final resonanceApi = Schrodinger(_substrateService.provider!);
    final multiDest = const multi_address.$MultiAddress().id(
      crypto.ss58ToAccountId(s: recipientAddress),
    );

    final call = resonanceApi.tx.reversibleTransfers.scheduleTransferWithDelay(
      dest: multiDest,
      amount: amount,
      delay: delay,
    );
    return call;
  }

  /// Schedule a reversible transfer with custom delay in seconds
  Future<Uint8List> scheduleReversibleTransferWithDelaySeconds({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
    void Function(ExtrinsicStatus)? onStatus,
  }) {
    // convert seconds to milliseconds for runtime
    final delay = qp.Timestamp(BigInt.from(delaySeconds) * BigInt.from(1000));
    return scheduleReversibleTransferWithDelay(
      account: account,
      recipientAddress: recipientAddress,
      amount: amount,
      delay: delay,
      onStatus: onStatus,
    );
  }

  /// Cancel a pending reversible transaction (theft deterrence - reverse a transaction)
  Future<Uint8List> cancelReversibleTransfer({
    required Account account,
    required H256 transactionId,
  }) async {
    try {
      final resonanceApi = Schrodinger(_substrateService.provider!);

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
  Future<Uint8List> executeTransfer({
    required Account account,
    required H256 transactionId,
  }) async {
    try {
      final resonanceApi = Schrodinger(_substrateService.provider!);

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
      final resonanceApi = Schrodinger(_substrateService.provider!);
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
      final resonanceApi = Schrodinger(_substrateService.provider!);

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
      final resonanceApi = Schrodinger(_substrateService.provider!);
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
  static qp.BlockNumberOrTimestamp delayFromMilliseconds(int milliseconds) {
    return qp.Timestamp(BigInt.from(milliseconds));
  }

  /// Helper method to create delay from block number
  static qp.BlockNumberOrTimestamp delayFromBlocks(int blocks) {
    return qp.BlockNumber(blocks);
  }

  /// Get constants related to reversible transfers
  Future<Map<String, dynamic>> getConstants() async {
    try {
      final resonanceApi = Schrodinger(_substrateService.provider!);
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
