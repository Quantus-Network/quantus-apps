import 'dart:async';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/extensions/duration_extension.dart';

class HighSecurityService {
  static final HighSecurityService _instance = HighSecurityService._internal();
  factory HighSecurityService() => _instance;
  HighSecurityService._internal();

  // ignore: unused_field
  final SubstrateService _substrateService = SubstrateService();
  final ReversibleTransfersService _reversibleTransfersService = ReversibleTransfersService();

  Future<void> setupHighSecurityAccount(Account account, String guardianAccountId, Duration safeguardDuration) async {
    _reversibleTransfersService.setHighSecurity(
      account: account,
      guardianAccountId: guardianAccountId,
      delay: safeguardDuration.qpTimestamp,
    );
  }

  // TODO replace with actual fee calculation
  Future<ExtrinsicFeeData> getHighSecuritySetupFee(Account account, HighSecurityData formData) async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      // Mock fetch
      return ExtrinsicFeeData(
        fee: BigInt.from(1000000000000000000), // 1.0
        blockHash: '0x0',
        blockNumber: 0,
      );
    } catch (e, stackTrace) {
      print('Failed to get setup fee: $e');
      print('Failed to get setup fee: $stackTrace');
      throw Exception('Failed to get setup fee: $e');
    }
  }

  Future<bool> isHighSecurity(Account account) async {
    await Future.delayed(const Duration(seconds: 1));
    // just for testing
    return account.name.startsWith('High');
  }
}
