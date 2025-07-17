import 'dart:async';
import 'dart:typed_data';
import 'package:polkadart/primitives/primitives.dart';
import 'package:quantus_sdk/generated/resonance/resonance.dart';
import 'package:quantus_sdk/generated/resonance/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/generated/resonance/types/pallet_recovery/recovery_config.dart';
import 'package:quantus_sdk/generated/resonance/types/pallet_recovery/active_recovery.dart';
import 'package:quantus_sdk/generated/resonance/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'substrate_service.dart';

/// Service for managing account recovery functionality
class RecoveryService {
  static final RecoveryService _instance = RecoveryService._internal();
  factory RecoveryService() => _instance;
  RecoveryService._internal();

  final SubstrateService _substrateService = SubstrateService();

  /// Create a recovery configuration for an account
  /// This makes the account recoverable by trusted friends
  Future<StreamSubscription<ExtrinsicStatus>> createRecoveryConfig({
    required Account account,
    required List<String> friendAddresses,
    required int threshold,
    required int delayPeriod,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final friends = friendAddresses.map((addr) => crypto.ss58ToAccountId(s: addr)).toList();

      // Create the call
      final call = resonanceApi.tx.recovery.createRecovery(
        friends: friends,
        threshold: threshold,
        delayPeriod: delayPeriod,
      );

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(account, call);
    } catch (e) {
      throw Exception('Failed to create recovery config: $e');
    }
  }

  /// Initiate recovery process for a lost account
  Future<StreamSubscription<ExtrinsicStatus>> initiateRecovery({
    required Account rescuerAccount,
    required String lostAccountAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccount = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: lostAccountAddress));

      // Create the call
      final call = resonanceApi.tx.recovery.initiateRecovery(account: lostAccount);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerAccount, call);
    } catch (e) {
      throw Exception('Failed to initiate recovery: $e');
    }
  }

  /// Vouch for an active recovery process (called by friends)
  Future<StreamSubscription<ExtrinsicStatus>> vouchForRecovery({
    required Account friendAccount,
    required String lostAccountAddress,
    required String rescuerAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccount = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: lostAccountAddress));
      final rescuer = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: rescuerAddress));

      // Create the call
      final call = resonanceApi.tx.recovery.vouchRecovery(lost: lostAccount, rescuer: rescuer);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(friendAccount, call);
    } catch (e) {
      throw Exception('Failed to vouch for recovery: $e');
    }
  }

  /// Claim recovery of a lost account (called by rescuer after threshold is met)
  Future<StreamSubscription<ExtrinsicStatus>> claimRecovery({
    required Account rescuerAccount,
    required String lostAccountAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccount = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: lostAccountAddress));

      // Create the call
      final call = resonanceApi.tx.recovery.claimRecovery(account: lostAccount);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerAccount, call);
    } catch (e) {
      throw Exception('Failed to claim recovery: $e');
    }
  }

  /// Close an active recovery process (called by the lost account owner)
  Future<StreamSubscription<ExtrinsicStatus>> closeRecovery({
    required Account lostAccount,
    required String rescuerAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final rescuer = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: rescuerAddress));

      // Create the call
      final call = resonanceApi.tx.recovery.closeRecovery(rescuer: rescuer);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(lostAccount, call);
    } catch (e) {
      throw Exception('Failed to close recovery: $e');
    }
  }

  /// Remove recovery configuration from account
  Future<StreamSubscription<ExtrinsicStatus>> removeRecoveryConfig({required Account senderAccount}) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);

      // Create the call
      final call = resonanceApi.tx.recovery.removeRecovery();

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(senderAccount, call);
    } catch (e) {
      throw Exception('Failed to remove recovery config: $e');
    }
  }

  /// Call a function as a recovered account (proxy call)
  Future<StreamSubscription<ExtrinsicStatus>> callAsRecovered({
    required Account rescuerAccount,
    required String recoveredAccountAddress,
    required RuntimeCall call,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final recoveredAccount = const multi_address.$MultiAddress().id(
        crypto.ss58ToAccountId(s: recoveredAccountAddress),
      );

      // Create the call
      final proxyCall = resonanceApi.tx.recovery.asRecovered(account: recoveredAccount, call: call);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerAccount, proxyCall);
    } catch (e) {
      throw Exception('Failed to call as recovered: $e');
    }
  }

  /// Cancel the ability to use a recovered account
  Future<StreamSubscription<ExtrinsicStatus>> cancelRecovered({
    required Account rescuerAccount,
    required String recoveredAccountAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final recoveredAccount = const multi_address.$MultiAddress().id(
        crypto.ss58ToAccountId(s: recoveredAccountAddress),
      );

      // Create the call
      final call = resonanceApi.tx.recovery.cancelRecovered(account: recoveredAccount);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerAccount, call);
    } catch (e) {
      throw Exception('Failed to cancel recovered: $e');
    }
  }

  /// Query recovery configuration for an account
  Future<RecoveryConfig?> getRecoveryConfig(String address) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final accountId = crypto.ss58ToAccountId(s: address);

      return await resonanceApi.query.recovery.recoverable(accountId);
    } catch (e) {
      throw Exception('Failed to get recovery config: $e');
    }
  }

  /// Query active recovery process
  Future<ActiveRecovery?> getActiveRecovery(String lostAccountAddress, String rescuerAddress) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccountId = crypto.ss58ToAccountId(s: lostAccountAddress);
      final rescuerId = crypto.ss58ToAccountId(s: rescuerAddress);

      return await resonanceApi.query.recovery.activeRecoveries(lostAccountId, rescuerId);
    } catch (e) {
      throw Exception('Failed to get active recovery: $e');
    }
  }

  /// Check if an account can act as proxy for a recovered account
  Future<String?> getProxyRecoveredAccount(String proxyAddress) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final proxyId = crypto.ss58ToAccountId(s: proxyAddress);

      final recoveredAccountId = await resonanceApi.query.recovery.proxy(proxyId);
      return recoveredAccountId != null
          ? crypto.toAccountId(
              obj: crypto.Keypair(publicKey: Uint8List.fromList(recoveredAccountId), secretKey: Uint8List(0)),
            )
          : null;
    } catch (e) {
      throw Exception('Failed to get proxy recovered account: $e');
    }
  }

  /// Check if account has recovery configuration
  Future<bool> hasRecoveryConfig(String address) async {
    try {
      final config = await getRecoveryConfig(address);
      return config != null;
    } catch (e) {
      throw Exception('Failed to check recovery config: $e');
    }
  }

  /// Check if recovery process is active
  Future<bool> isRecoveryActive(String lostAccountAddress, String rescuerAddress) async {
    try {
      final activeRecovery = await getActiveRecovery(lostAccountAddress, rescuerAddress);
      return activeRecovery != null;
    } catch (e) {
      throw Exception('Failed to check recovery status: $e');
    }
  }

  /// Get recovery progress (how many vouches received vs threshold)
  Future<Map<String, int>> getRecoveryProgress(String lostAccountAddress, String rescuerAddress) async {
    try {
      final activeRecovery = await getActiveRecovery(lostAccountAddress, rescuerAddress);
      final config = await getRecoveryConfig(lostAccountAddress);

      if (activeRecovery == null || config == null) {
        throw Exception('No active recovery or config found');
      }

      return {
        'vouches': activeRecovery.friends.length,
        'threshold': config.threshold,
        'delayPeriod': config.delayPeriod,
        'created': activeRecovery.created,
      };
    } catch (e) {
      throw Exception('Failed to get recovery progress: $e');
    }
  }

  /// Get recovery constants
  Future<Map<String, dynamic>> getConstants() async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final constants = resonanceApi.constant.recovery;

      return {
        'configDepositBase': constants.configDepositBase,
        'friendDepositFactor': constants.friendDepositFactor,
        'maxFriends': constants.maxFriends,
        'recoveryDeposit': constants.recoveryDeposit,
      };
    } catch (e) {
      throw Exception('Failed to get recovery constants: $e');
    }
  }

  /// Helper to create a balance transfer call for recovered account
  Balances createBalanceTransferCall(String recipientAddress, BigInt amount) {
    final resonanceApi = Resonance(_substrateService.provider!);
    final accountID = crypto.ss58ToAccountId(s: recipientAddress);
    final dest = const multi_address.$MultiAddress().id(accountID);
    final call = resonanceApi.tx.balances.transferAllowDeath(dest: dest, value: amount);
    return call;
  }

  /// Convenience method to transfer balance as recovered account
  Future<StreamSubscription<ExtrinsicStatus>> transferAsRecovered({
    required Account rescuerAccount,
    required String recoveredAccountAddress,
    required String recipientAddress,
    required BigInt amount,
  }) async {
    try {
      final transferCall = createBalanceTransferCall(recipientAddress, amount);
      return await callAsRecovered(
        rescuerAccount: rescuerAccount,
        recoveredAccountAddress: recoveredAccountAddress,
        call: transferCall,
      );
    } catch (e) {
      throw Exception('Failed to transfer as recovered: $e');
    }
  }
}
