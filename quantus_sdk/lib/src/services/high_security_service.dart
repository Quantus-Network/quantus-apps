import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:quantus_sdk/generated/planck/planck.dart';
import 'package:quantus_sdk/generated/planck/types/qp_scheduler/block_number_or_timestamp.dart' as qp;
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

  Future<List<EntrustedAccount>> getEntrustedAccounts(Account account) async {
    final accounts = await AccountsService().getAccounts();
    String getAccountName(String ss58Address) =>
        accounts.firstWhereOrNull((a) => a.accountId == ss58Address)?.name ?? 'Entrusted Account';
    return (await _reversibleTransfersService.getInterceptedAccounts(account.accountId))
        .mapIndexed(
          (index, accountId) => EntrustedAccount(
            parentAccountId: account.accountId,
            index: index,
            name: getAccountName(accountId),
            accountId: accountId,
          ),
        )
        .toList();
  }

  Future<Account?> getGuardianAccount(EntrustedAccount entrustedAccount) async {
    final accounts = await AccountsService().getAccounts();
    return accounts.firstWhere((a) => a.accountId == entrustedAccount.parentAccountId);
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

  Future<Uint8List> pullAllFunds(String lostAccountAddress, Account guardianAccount) async {
    print('pullAllFunds: $lostAccountAddress, $guardianAccount');
    // 1. Initiate recovery (rescuer = guardian)
    Utility batchCall = _getPullAllFundsCall(lostAccountAddress, guardianAccount);
    // Submit batch signed by guardian
    return await _substrateService.submitExtrinsic(guardianAccount, batchCall);
  }

  Future<ExtrinsicFeeData> getPullAllFundsFee(String lostAccountAddress, Account guardianAccount) async {
    // Batch all calls
    final batchCall = _getPullAllFundsCall(lostAccountAddress, guardianAccount);

    // Get transaction fee
    final transactionFee = await _substrateService.getFeeForCall(guardianAccount, batchCall);

    // Add recovery deposit
    final recoveryDeposit = RecoveryService().recoveryDeposit;

    return ExtrinsicFeeData(
      fee: transactionFee.fee + recoveryDeposit,
      blockHash: transactionFee.blockHash,
      blockNumber: transactionFee.blockNumber,
    );
  }

  Utility _getPullAllFundsCall(String lostAccountAddress, Account guardianAccount) {
    final calls = <RuntimeCall>[];

    final recoveryService = RecoveryService();
    final balancesService = BalancesService();
    final quantusApi = Planck(_substrateService.provider!);

    // 1. Initiate recovery (rescuer = guardian)
    calls.add(recoveryService.getInitiateRecoveryCall(lostAccountAddress));

    // 2. Vouch for recovery (friend = guardian)
    calls.add(recoveryService.getVouchRecoveryCall(lostAccountAddress, guardianAccount.accountId));

    // 3. Claim recovery (rescuer = guardian)
    calls.add(recoveryService.getClaimRecoveryCall(lostAccountAddress));

    // 4. Transfer all funds to guardian (as recovered)
    final transferAllCall = balancesService.getTransferAllCall(guardianAccount.accountId, keepAlive: false);
    calls.add(recoveryService.getAsRecoveredCall(lostAccountAddress, transferAllCall));

    // Batch all calls
    final batchCall = quantusApi.tx.utility.batch(calls: calls);
    return batchCall;
  }
}
