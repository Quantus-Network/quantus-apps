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

  Future<ExtrinsicFeeData> getHighSecuritySetupFee(
    Account account,
    String guardianAccountId,
    Duration safeguardDuration,
  ) async {
    return _reversibleTransfersService.getHighSecuritySetupFee(account, guardianAccountId, safeguardDuration);
  }

  Future<bool> isHighSecurity(Account account) async {
    await Future.delayed(const Duration(seconds: 1));
    // just for testing
    return account.name.startsWith('High');
  }
}
