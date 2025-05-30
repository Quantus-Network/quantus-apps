// ignore_for_file: no_leading_underscores_for_library_prefixes
import '../types/pallet_faucet/pallet/call.dart' as _i3;
import '../types/resonance_runtime/runtime_call.dart' as _i1;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i2;

class Txs {
  const Txs();

  /// mint new tokens
  _i1.Faucet mintNewTokens({
    required _i2.MultiAddress dest,
    required BigInt seed,
  }) {
    return _i1.Faucet(_i3.MintNewTokens(
      dest: dest,
      seed: seed,
    ));
  }
}

class Constants {
  Constants();

  final BigInt maxTokenAmount = BigInt.from(1000000000000000);

  final BigInt defaultMintAmount = BigInt.from(10000000000000);
}
