import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/planck/planck.dart';
import 'package:quantus_sdk/generated/planck/types/pallet_reversible_transfers/high_security_account_data.dart';
import 'package:quantus_sdk/generated/planck/types/pallet_reversible_transfers/pending_transfer.dart';
import 'package:quantus_sdk/generated/planck/types/primitive_types/h256.dart';
import 'package:quantus_sdk/generated/planck/types/qp_scheduler/block_number_or_timestamp.dart' as qp;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/extensions/duration_extension.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/extrinsic_fee_data.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

import 'substrate_service.dart';

/// Service for managing reversible transfers for theft deterrence and ad hoc transfers
class ReversibleTransfersService {
  static final ReversibleTransfersService _instance = ReversibleTransfersService._internal();
  factory ReversibleTransfersService() => _instance;
  ReversibleTransfersService._internal();

  final SubstrateService _substrateService = SubstrateService();

  /// Schedule a reversible transfer using account's default settings
  Future<Uint8List> scheduleReversibleTransfer({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
  }) async {
    try {
      final quantusApi = Planck(_substrateService.provider!);
      final multiDest = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: recipientAddress));

      // Create the call
      final call = quantusApi.tx.reversibleTransfers.scheduleTransfer(dest: multiDest, amount: amount);
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
    ReversibleTransfers call = getReversibleTransferCall(recipientAddress, amount, delay);

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
    ReversibleTransfers call = getReversibleTransferCall(recipientAddress, amount, delay);

    // Submit the transaction using substrate service
    return _substrateService.getFeeForCall(account, call);
  }

  ReversibleTransfers getReversibleTransferCall(
    String recipientAddress,
    BigInt amount,
    qp.BlockNumberOrTimestamp delay,
  ) {
    final quantusApi = Planck(_substrateService.provider!);
    final multiDest = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: recipientAddress));

    final call = quantusApi.tx.reversibleTransfers.scheduleTransferWithDelay(
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
    final delay = Duration(seconds: delaySeconds).qpTimestamp;
    return scheduleReversibleTransferWithDelay(
      account: account,
      recipientAddress: recipientAddress,
      amount: amount,
      delay: delay,
      onStatus: onStatus,
    );
  }

  /// Cancel a pending reversible transaction (theft deterrence - reverse a transaction)
  Future<Uint8List> cancelReversibleTransfer({required Account account, required H256 transactionId}) async {
    try {
      final quantusApi = Planck(_substrateService.provider!);

      // Create the call
      final call = quantusApi.tx.reversibleTransfers.cancel(txId: transactionId);

      // Submit the transaction using substrate service
      return _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to cancel reversible transfer: $e');
    }
  }

  /// Query account's reversibility configuration
  Future<HighSecurityAccountData?> getHighSecurityConfig(String address) async {
    print('getHighSecurityConfig: $address');
    try {
      final quantusApi = Planck(_substrateService.provider!);
      final accountId = crypto.ss58ToAccountId(s: address);

      return await quantusApi.query.reversibleTransfers.highSecurityAccounts(accountId);
    } catch (e) {
      throw Exception('Failed to get account reversibility config: $e');
    }
  }

  /// Query pending transfer details
  Future<PendingTransfer?> getPendingTransfer(H256 transactionId) async {
    try {
      final quantusApi = Planck(_substrateService.provider!);

      return await quantusApi.query.reversibleTransfers.pendingTransfers(transactionId);
    } catch (e) {
      throw Exception('Failed to get pending transfer: $e');
    }
  }

  /// Get all pending transfers for an account
  Future<List<PendingTransfer>> getAccountPendingTransfers(String address) async {
    try {
      final quantusApi = Planck(_substrateService.provider!);
      final accountId = crypto.ss58ToAccountId(s: address);
      final txIds = await quantusApi.query.reversibleTransfers.pendingTransfersBySender(accountId);

      final results = <PendingTransfer>[];
      for (final txId in txIds) {
        final transfer = await quantusApi.query.reversibleTransfers.pendingTransfers(txId);
        if (transfer != null) results.add(transfer);
      }
      return results;
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
      final quantusApi = Planck(_substrateService.provider!);
      final constants = quantusApi.constant.reversibleTransfers;

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

  // ==============================================================================
  // High security accounts
  // ==============================================================================

  // Set the account has a high security account with a guardian
  Future<Uint8List> setHighSecurity({
    required Account account,
    required String guardianAccountId,
    required qp.BlockNumberOrTimestamp delay,
  }) async {
    final delayValue = delay is qp.BlockNumber
        ? '${(delay).value0} blocks'
        : delay is qp.Timestamp
        ? '${(delay).value0} ms'
        : delay.toJson().toString();
    print('setHighSecurity: ${account.accountId}, $guardianAccountId, $delayValue');
    try {
      final quantusApi = Planck(_substrateService.provider!);
      final guardianAccountId32 = crypto.ss58ToAccountId(s: guardianAccountId);

      // Create the call
      ReversibleTransfers call = quantusApi.tx.reversibleTransfers.setHighSecurity(
        delay: delay,
        guardian: guardianAccountId32,
      );
      print('Encoded Call: ${call.encode()}');
      print('Encoded Call Hex: ${hex.encode(call.encode())}');

      // Submit the transaction using substrate service
      final res = await _substrateService.submitExtrinsic(account, call);

      print('setHighSecurity done with result: $res');
      return res;
    } catch (e) {
      print('Failed to enable high security: $e');
      throw Exception('Failed to enable high security: $e');
    }
  }

  Future<bool> isHighSecurity(String address) async {
    print('isHighSecurity: $address');
    try {
      final config = await getHighSecurityConfig(address);
      return config != null;
    } catch (e) {
      throw Exception('Failed to check high security status: $e');
    }
  }

  Future<Uint8List> interceptTransaction({required Account guardianAccount, required H256 transactionId}) async {
    return cancelReversibleTransfer(account: guardianAccount, transactionId: transactionId);
  }

  /// Check if account is a guardian (interceptor) for any accounts
  Future<bool> isGuardian(String address) async {
    print('isGuardian: $address');
    return (await getInterceptedAccounts(address)).isNotEmpty;
  }

  /// Get list of accounts that the given account is a guardian (interceptor) for
  Future<List<String>> getInterceptedAccounts(String guardianAddress) async {
    print('getInterceptedAccounts: $guardianAddress');

    try {
      final quantusApi = Planck(_substrateService.provider!);
      final accountId = crypto.ss58ToAccountId(s: guardianAddress);
      final interceptedAccounts = await quantusApi.query.reversibleTransfers.guardianIndex(accountId);

      List<String> result = interceptedAccounts.map((id) {
        final address = AddressExtension.ss58AddressFromBytes(Uint8List.fromList(id));
        print('intercepted account: $address');
        return address;
      }).toList();

      return result;
    } catch (e) {
      throw Exception('Failed to get intercepted accounts: $e');
    }
  }

  Future<ExtrinsicFeeData> getHighSecuritySetupFee(
    Account account,
    String guardianAccountId,
    Duration safeguardDuration,
  ) async {
    final delay = safeguardDuration.qpTimestamp;
    final quantusApi = Planck(_substrateService.provider!);
    final call = quantusApi.tx.reversibleTransfers.setHighSecurity(
      delay: delay,
      guardian: crypto.ss58ToAccountId(s: guardianAccountId),
    );
    return _substrateService.getFeeForCall(account, call);
  }
}
