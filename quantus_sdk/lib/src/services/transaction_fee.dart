import 'package:quantus_sdk/generated/planck/pallets/system.dart' as system_pallet;

/// Runtime `LENGTH_FEE_MULTIPLIER`: one UNIT per megabyte of extrinsic. The
/// only fee parameter the metadata does not carry.
final BigInt lengthFeePerByte = BigInt.from(1000000);

/// `TransactionPayment::compute_fee` for a signed extrinsic of [length] bytes
/// whose call plus transaction extensions weigh [dispatchWeight] ref-time.
/// `WeightToFee` is the identity and the fee multiplier a constant 1, so there
/// is no congestion component: the fee is fully determined by the shipped
/// metadata's base extrinsic weight, the length and the dispatch weight.
BigInt inclusionFee({required int length, required BigInt dispatchWeight}) =>
    system_pallet.Constants().blockWeights.perClass.normal.baseExtrinsic.refTime +
    BigInt.from(length) * lengthFeePerByte +
    dispatchWeight;
