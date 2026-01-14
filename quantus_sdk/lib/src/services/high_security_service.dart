import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:quantus_sdk/generated/schrodinger/types/qp_scheduler/block_number_or_timestamp.dart' as qp;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/extensions/duration_extension.dart';

class HighSecurityService {
  static final HighSecurityService _instance = HighSecurityService._internal();
  factory HighSecurityService() => _instance;
  HighSecurityService._internal();

  // ignore: unused_field
  final SubstrateService _substrateService = SubstrateService();
  final ReversibleTransfersService _reversibleTransfersService = ReversibleTransfersService();

  Future<Uint8List> setHighSecurity(Account account, String guardianAccountId, Duration safeguardDuration) async {
    return await _reversibleTransfersService.setHighSecurity(
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
    final transactionFee = await _reversibleTransfersService.getHighSecuritySetupFee(
      account,
      guardianAccountId,
      safeguardDuration,
    );
    final recoveryPalletFee = RecoveryService().configDepositBase + RecoveryService().friendDepositFactor;

    return ExtrinsicFeeData(
      fee: transactionFee.fee + recoveryPalletFee,
      blockHash: transactionFee.blockHash,
      blockNumber: transactionFee.blockNumber,
    );
  }

  Future<bool> isHighSecurity(Account account) async {
    return await getHighSecurityConfig(account.accountId) != null;
  }

  Future<bool> isGuardian(Account account) async {
    return await _reversibleTransfersService.isGuardian(account.accountId);
  }

  Future<List<Account>> getEntrustedAccounts(Account account) async {
    final accounts = await AccountsService().getAccounts();
    Account? mapExistingAccount(String ss58Address) => accounts.firstWhereOrNull((a) => a.accountId == ss58Address);
    return (await _reversibleTransfersService.getInterceptedAccounts(
      account.accountId,
    )).map((account) => mapExistingAccount(account) ?? Account.fromSs58Address(account)).toList();
  }

  Future<HighSecurityData?> getHighSecurityConfig(String address) async {
    final hsData = await _reversibleTransfersService.getHighSecurityConfig(address);
    print('getHighSecurityConfig: $address -> $hsData');
    if (hsData != null) {
      final accountId = AddressExtension.ss58AddressFromBytes(Uint8List.fromList(hsData.interceptor));
      if (hsData.delay is! qp.Timestamp) {
        throw ArgumentError('Expected timestamp delay, got block number');
      }
      final safeguardWindow = DurationToTimestampExtension.fromQpTimestamp(hsData.delay as qp.Timestamp);
      return HighSecurityData(guardianAccountId: accountId, safeguardWindow: safeguardWindow);
    } else {
      // not a high security account
      return null;
    }
  }
}
