import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class BalancesService {
  static final BalancesService _instance = BalancesService._internal();
  factory BalancesService() => _instance;
  BalancesService._internal();

  final SubstrateService _substrateService = SubstrateService();

  /// Inclusion fee for a `transfer_allow_death` of [amount] to [targetAddress],
  /// from `payment_queryInfo` on a dummy-signed extrinsic. Dummy-signed so this
  /// never prompts for a password or device; the node prices length and weight
  /// from the encoded extrinsic, not the signature bytes.
  Future<ExtrinsicFeeData> getBalanceTransferFee(Account account, String targetAddress, BigInt amount) =>
      _substrateService.getFeeForCall(account, getBalanceTransferCall(targetAddress, amount));

  Balances getBalanceTransferCall(String targetAddress, BigInt amount) => _transferCall(_dest(targetAddress), amount);

  Balances getTransferAllCall(String targetAddress, {bool keepAlive = false}) =>
      const balances_pallet.Txs().transferAll(dest: _dest(targetAddress), keepAlive: keepAlive);

  multi_address.MultiAddress _dest(String targetAddress) =>
      const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: targetAddress));

  Balances _transferCall(multi_address.MultiAddress dest, BigInt value) =>
      const balances_pallet.Txs().transferAllowDeath(dest: dest, value: value);
}
