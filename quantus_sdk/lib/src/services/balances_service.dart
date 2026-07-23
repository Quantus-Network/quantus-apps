import 'dart:async';
import 'dart:typed_data';

import 'package:quantus_sdk/generated/planck/planck.dart';
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/utils/print.dart';

class BalancesService {
  static final BalancesService _instance = BalancesService._internal();
  factory BalancesService() => _instance;
  BalancesService._internal();

  final SubstrateService _substrateService = SubstrateService();

  Future<Uint8List> balanceTransfer(Account account, String targetAddress, BigInt amount) async {
    try {
      Balances runtimeCall = getBalanceTransferCall(targetAddress, amount);
      // Submit the extrinsic and return its result
      return await _substrateService.submitExtrinsic(account, runtimeCall);
    } catch (e, stackTrace) {
      quantusDebugPrint('Failed to transfer balance: $e');
      quantusDebugPrint('Failed to transfer balance: $stackTrace');
      throw Exception('Failed to transfer balance: $e');
    }
  }

  Future<ExtrinsicFeeData> getBalanceTransferFee(Account account, String targetAddress, BigInt amount) async {
    try {
      Balances runtimeCall = getBalanceTransferCall(targetAddress, amount);
      // Submit the extrinsic and return its result
      return await _substrateService.getFeeForCall(account, runtimeCall);
    } catch (e, stackTrace) {
      quantusDebugPrint('Failed to transfer balance: $e');
      quantusDebugPrint('Failed to transfer balance: $stackTrace');
      throw Exception('Failed to transfer balance: $e');
    }
  }

  Balances getBalanceTransferCall(String targetAddress, BigInt amount) {
    final quantusApi = Planck(_substrateService.provider!);
    final multiDest = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: targetAddress));
    final runtimeCall = quantusApi.tx.balances.transferAllowDeath(dest: multiDest, value: amount);
    return runtimeCall;
  }

  Balances getTransferAllCall(String targetAddress, {bool keepAlive = false}) {
    final quantusApi = Planck(_substrateService.provider!);
    final multiDest = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: targetAddress));
    final runtimeCall = quantusApi.tx.balances.transferAll(dest: multiDest, keepAlive: keepAlive);
    return runtimeCall;
  }
}
