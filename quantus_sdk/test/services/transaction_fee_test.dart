import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/system.dart' as system_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';

/// `payment_queryInfo` on a1-planck (spec 144) for a dummy-signed
/// `transfer_allow_death` of 10 QUAN with a 1-byte nonce: 7303 bytes,
/// weight.ref_time 5_551_728_000, partialFee 12_962_885_000.
final BigInt _liveDispatchWeight = BigInt.from(5551728000);
final BigInt _livePartialFee = BigInt.from(12962885000);
final BigInt _tenQuan = BigInt.from(10).pow(13);

void main() {
  test('inclusion fee reproduces the chain fee from length and dispatch weight', () {
    expect(system_pallet.Constants().blockWeights.perClass.normal.baseExtrinsic.refTime, BigInt.from(108157000));
    expect(inclusionFee(length: 7303, dispatchWeight: _liveDispatchWeight), _livePartialFee);
  });

  test('signed extrinsic length sizes the nonce at its 4-byte maximum', () {
    final dest = const multi_address.$MultiAddress().id(List<int>.filled(32, 2));
    int length(BigInt amount) => SubstrateService().signedExtrinsicLength(
      const balances_pallet.Txs().transferAllowDeath(dest: dest, value: amount),
    );

    expect(length(_tenQuan), 7303 + 3);
    expect(length(BigInt.from(10).pow(10)), 7303 + 3 - 1);
  });

  test('transfer fee is the chain fee plus the nonce headroom', () {
    final fee = BalancesService().transferFee(_tenQuan, dispatchWeight: _liveDispatchWeight);
    expect(fee, _livePartialFee + lengthFeePerByte * BigInt.from(3));
  });
}
