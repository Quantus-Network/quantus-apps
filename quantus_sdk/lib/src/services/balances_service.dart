import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class BalancesService {
  static final BalancesService _instance = BalancesService._internal();
  factory BalancesService() => _instance;
  BalancesService._internal();

  final SubstrateService _substrateService = SubstrateService();

  /// Every recipient is a `MultiAddress::Id`, so any one sizes a transfer.
  static final multi_address.MultiAddress _anyDest = const multi_address.$MultiAddress().id(List<int>.filled(32, 0));

  ({int specVersion, BigInt weight})? _transferDispatchWeight;

  /// Ref-time a signed `transfer_allow_death` is charged for (call plus every
  /// transaction extension). Probed once per runtime version and cached; send
  /// flows prefetch it on entry so the amount screen never waits on it.
  Future<BigInt> transferDispatchWeight() async {
    final specVersion = (await _substrateService.getRuntimeVersion()).specVersion;
    final cached = _transferDispatchWeight;
    if (cached != null && cached.specVersion == specVersion) return cached.weight;
    final weight = await _substrateService.queryDispatchWeight(_transferCall(_anyDest, BigInt.zero));
    _transferDispatchWeight = (specVersion: specVersion, weight: weight);
    return weight;
  }

  /// Fee of a transfer of [amount], computed locally: base and length fee from
  /// the shipped metadata, [dispatchWeight] from [transferDispatchWeight].
  /// Only the compact-encoded amount varies the length.
  BigInt transferFee(BigInt amount, {required BigInt dispatchWeight, required DilithiumScheme scheme}) => inclusionFee(
    length: _substrateService.signedExtrinsicLength(_transferCall(_anyDest, amount), scheme),
    dispatchWeight: dispatchWeight,
  );

  Balances getBalanceTransferCall(String targetAddress, BigInt amount) => _transferCall(_dest(targetAddress), amount);

  Balances getTransferAllCall(String targetAddress, {bool keepAlive = false}) =>
      const balances_pallet.Txs().transferAll(dest: _dest(targetAddress), keepAlive: keepAlive);

  multi_address.MultiAddress _dest(String targetAddress) =>
      const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: targetAddress));

  Balances _transferCall(multi_address.MultiAddress dest, BigInt value) =>
      const balances_pallet.Txs().transferAllowDeath(dest: dest, value: value);
}
