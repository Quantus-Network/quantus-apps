import 'dart:async';
import 'dart:typed_data';

import 'package:quantus_sdk/generated/schrodinger/schrodinger.dart';
import 'package:quantus_sdk/generated/schrodinger/types/sp_runtime/multiaddress/multi_address.dart'
    as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class BalancesService {
  static final BalancesService _instance = BalancesService._internal();
  factory BalancesService() => _instance;
  BalancesService._internal();

  final SubstrateService _substrateService = SubstrateService();

  Future<Uint8List> balanceTransfer(
    Account account,
    String targetAddress,
    BigInt amount,
  ) async {
    try {
      Balances runtimeCall = getBalanceTransferCall(targetAddress, amount);
      // Submit the extrinsic and return its result
      return await _substrateService.submitExtrinsic(account, runtimeCall);
    } catch (e, stackTrace) {
      print('Failed to transfer balance: $e');
      print('Failed to transfer balance: $stackTrace');
      throw Exception('Failed to transfer balance: $e');
    }
  }

  Future<ExtrinsicFeeData> getBalanceTransferFee(
    Account account,
    String targetAddress,
    BigInt amount,
  ) async {
    try {
      Balances runtimeCall = getBalanceTransferCall(targetAddress, amount);
      // Submit the extrinsic and return its result
      return await _substrateService.getFeeForCall(account, runtimeCall);
    } catch (e, stackTrace) {
      print('Failed to transfer balance: $e');
      print('Failed to transfer balance: $stackTrace');
      throw Exception('Failed to transfer balance: $e');
    }
  }

  Balances getBalanceTransferCall(String targetAddress, BigInt amount) {
    final resonanceApi =  Schrodinger(_substrateService.provider!);
    final multiDest = const multi_address.$MultiAddress().id(
      crypto.ss58ToAccountId(s: targetAddress),
    );
    final runtimeCall = resonanceApi.tx.balances.transferAllowDeath(
      dest: multiDest,
      value: amount,
    );
    return runtimeCall;
  }
}
