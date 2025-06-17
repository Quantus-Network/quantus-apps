import 'dart:typed_data';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/resonance/resonance.dart';
import 'package:quantus_sdk/generated/resonance/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/generated/resonance/types/sp_core/crypto/account_id32.dart';
import 'package:quantus_sdk/generated/resonance/types/pallet_recovery/recovery_config.dart';
import 'package:quantus_sdk/generated/resonance/types/pallet_recovery/active_recovery.dart';
import 'package:quantus_sdk/generated/resonance/types/quantus_runtime/runtime_call.dart';
import 'substrate_service.dart';
import '../constants/app_constants.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

/// Service for managing account recovery functionality
class RecoveryService {
  static final RecoveryService _instance = RecoveryService._internal();
  factory RecoveryService() => _instance;
  RecoveryService._internal();

  final SubstrateService _substrateService = SubstrateService();

  /// Create a recovery configuration for an account
  /// This makes the account recoverable by trusted friends
  Future<String> createRecoveryConfig({
    required String senderSeed,
    required List<String> friendAddresses,
    required int threshold,
    required int delayPeriod,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);

      // Convert friend addresses to AccountId32
      final friends = friendAddresses.map((addr) => Address.decode(addr).pubkey).toList();

      // Create the call
      final call = resonanceApi.tx.recovery.createRecovery(
        friends: friends,
        threshold: threshold,
        delayPeriod: delayPeriod,
      );

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(senderSeed, call);
    } catch (e) {
      throw Exception('Failed to create recovery config: $e');
    }
  }

  /// Initiate recovery process for a lost account
  Future<String> initiateRecovery({
    required String rescuerSeed,
    required String lostAccountAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccount = const multi_address.$MultiAddress().id(Address.decode(lostAccountAddress).pubkey);

      // Create the call
      final call = resonanceApi.tx.recovery.initiateRecovery(account: lostAccount);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerSeed, call);
    } catch (e) {
      throw Exception('Failed to initiate recovery: $e');
    }
  }

  /// Vouch for an active recovery process (called by friends)
  Future<String> vouchForRecovery({
    required String friendSeed,
    required String lostAccountAddress,
    required String rescuerAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccount = const multi_address.$MultiAddress().id(Address.decode(lostAccountAddress).pubkey);
      final rescuer = const multi_address.$MultiAddress().id(Address.decode(rescuerAddress).pubkey);

      // Create the call
      final call = resonanceApi.tx.recovery.vouchRecovery(
        lost: lostAccount,
        rescuer: rescuer,
      );

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(friendSeed, call);
    } catch (e) {
      throw Exception('Failed to vouch for recovery: $e');
    }
  }

  /// Claim recovery of a lost account (called by rescuer after threshold is met)
  Future<String> claimRecovery({
    required String rescuerSeed,
    required String lostAccountAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccount = const multi_address.$MultiAddress().id(Address.decode(lostAccountAddress).pubkey);

      // Create the call
      final call = resonanceApi.tx.recovery.claimRecovery(account: lostAccount);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerSeed, call);
    } catch (e) {
      throw Exception('Failed to claim recovery: $e');
    }
  }

  /// Close an active recovery process (called by the lost account owner)
  Future<String> closeRecovery({
    required String lostAccountSeed,
    required String rescuerAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final rescuer = const multi_address.$MultiAddress().id(Address.decode(rescuerAddress).pubkey);

      // Create the call
      final call = resonanceApi.tx.recovery.closeRecovery(rescuer: rescuer);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(lostAccountSeed, call);
    } catch (e) {
      throw Exception('Failed to close recovery: $e');
    }
  }

  /// Remove recovery configuration from account
  Future<String> removeRecoveryConfig({required String senderSeed}) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);

      // Create the call
      final call = resonanceApi.tx.recovery.removeRecovery();

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(senderSeed, call);
    } catch (e) {
      throw Exception('Failed to remove recovery config: $e');
    }
  }

  /// Call a function as a recovered account (proxy call)
  Future<String> callAsRecovered({
    required String rescuerSeed,
    required String recoveredAccountAddress,
    required RuntimeCall call,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final recoveredAccount = const multi_address.$MultiAddress().id(Address.decode(recoveredAccountAddress).pubkey);

      // Create the call
      final proxyCall = resonanceApi.tx.recovery.asRecovered(
        account: recoveredAccount,
        call: call,
      );

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerSeed, proxyCall);
    } catch (e) {
      throw Exception('Failed to call as recovered: $e');
    }
  }

  /// Cancel the ability to use a recovered account
  Future<String> cancelRecovered({
    required String rescuerSeed,
    required String recoveredAccountAddress,
  }) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final recoveredAccount = const multi_address.$MultiAddress().id(Address.decode(recoveredAccountAddress).pubkey);

      // Create the call
      final call = resonanceApi.tx.recovery.cancelRecovered(account: recoveredAccount);

      // Submit the transaction using substrate service
      return await _substrateService.submitExtrinsic(rescuerSeed, call);
    } catch (e) {
      throw Exception('Failed to cancel recovered: $e');
    }
  }

  /// Query recovery configuration for an account
  Future<RecoveryConfig?> getRecoveryConfig(String address) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final accountId = Address.decode(address).pubkey;

      return await resonanceApi.query.recovery.recoverable(accountId);
    } catch (e) {
      throw Exception('Failed to get recovery config: $e');
    }
  }

  /// Query active recovery process
  Future<ActiveRecovery?> getActiveRecovery(String lostAccountAddress, String rescuerAddress) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final lostAccountId = Address.decode(lostAccountAddress).pubkey;
      final rescuerId = Address.decode(rescuerAddress).pubkey;

      return await resonanceApi.query.recovery.activeRecoveries(lostAccountId, rescuerId);
    } catch (e) {
      throw Exception('Failed to get active recovery: $e');
    }
  }

  /// Check if an account can act as proxy for a recovered account
  Future<String?> getProxyRecoveredAccount(String proxyAddress) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final proxyId = Address.decode(proxyAddress).pubkey;

      final recoveredAccountId = await resonanceApi.query.recovery.proxy(proxyId);
      return recoveredAccountId != null ? Address.encode(recoveredAccountId, AppConstants.ss58Prefix) : null;
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
      final constants = resonanceApi.constants.recovery;

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
  RuntimeCall createBalanceTransferCall(String recipientAddress, BigInt amount) {
    final resonanceApi = Resonance(_substrateService.provider!);
    final dest = const multi_address.$MultiAddress().id(Address.decode(recipientAddress).pubkey);
    return RuntimeCall.balances(resonanceApi.tx.balances.transferKeepAlive(dest: dest, value: amount));
  }

  /// Convenience method to transfer balance as recovered account
  Future<String> transferAsRecovered({
    required String rescuerSeed,
    required String recoveredAccountAddress,
    required String recipientAddress,
    required BigInt amount,
  }) async {
    try {
      final transferCall = createBalanceTransferCall(recipientAddress, amount);
      return await callAsRecovered(
        rescuerSeed: rescuerSeed,
        recoveredAccountAddress: recoveredAccountAddress,
        call: transferCall,
      );
    } catch (e) {
      throw Exception('Failed to transfer as recovered: $e');
    }
  }
}
