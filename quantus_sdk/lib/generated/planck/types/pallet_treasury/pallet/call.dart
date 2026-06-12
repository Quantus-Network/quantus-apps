// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../sp_arithmetic/per_things/permill.dart' as _i4;
import '../../sp_core/crypto/account_id32.dart' as _i3;

/// Contains a variant per dispatchable extrinsic that this pallet has.
abstract class Call {
  const Call();

  factory Call.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $CallCodec codec = $CallCodec();

  static const $Call values = $Call();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, Map<String, dynamic>> toJson();
}

class $Call {
  const $Call();

  SetTreasuryAccount setTreasuryAccount({required _i3.AccountId32 account}) {
    return SetTreasuryAccount(account: account);
  }

  SetTreasuryPortion setTreasuryPortion({required _i4.Permill portion}) {
    return SetTreasuryPortion(portion: portion);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return SetTreasuryAccount._decode(input);
      case 1:
        return SetTreasuryPortion._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case SetTreasuryAccount:
        (value as SetTreasuryAccount).encodeTo(output);
        break;
      case SetTreasuryPortion:
        (value as SetTreasuryPortion).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case SetTreasuryAccount:
        return (value as SetTreasuryAccount)._sizeHint();
      case SetTreasuryPortion:
        return (value as SetTreasuryPortion)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Set the treasury account. Root only. Zero address is rejected (funds would be locked).
///
/// **Important**: This only changes where *future* mining rewards are sent. Any balance
/// that has already accumulated in the current treasury account is NOT automatically
/// migrated to the new account. If you need to move existing funds, perform a separate
/// balance transfer (e.g., via governance proposal) after updating the account.
class SetTreasuryAccount extends Call {
  const SetTreasuryAccount({required this.account});

  factory SetTreasuryAccount._decode(_i1.Input input) {
    return SetTreasuryAccount(account: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i3.AccountId32 account;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'set_treasury_account': {'account': account.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(account);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    const _i1.U8ArrayCodec(32).encodeTo(account, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SetTreasuryAccount && _i5.listsEqual(other.account, account);

  @override
  int get hashCode => account.hashCode;
}

/// Set the treasury portion (Permill, 0–100%). Root only.
class SetTreasuryPortion extends Call {
  const SetTreasuryPortion({required this.portion});

  factory SetTreasuryPortion._decode(_i1.Input input) {
    return SetTreasuryPortion(portion: _i1.U32Codec.codec.decode(input));
  }

  /// Permill
  final _i4.Permill portion;

  @override
  Map<String, Map<String, int>> toJson() => {
    'set_treasury_portion': {'portion': portion},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i4.PermillCodec().sizeHint(portion);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i1.U32Codec.codec.encodeTo(portion, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is SetTreasuryPortion && other.portion == portion;

  @override
  int get hashCode => portion.hashCode;
}
