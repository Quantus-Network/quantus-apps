// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// The `Event` enum of this pallet
abstract class Event {
  const Event();

  factory Event.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $EventCodec codec = $EventCodec();

  static const $Event values = $Event();

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

class $Event {
  const $Event();

  AirdropCreated airdropCreated({
    required int airdropId,
    required List<int> merkleRoot,
  }) {
    return AirdropCreated(
      airdropId: airdropId,
      merkleRoot: merkleRoot,
    );
  }

  AirdropFunded airdropFunded({
    required int airdropId,
    required BigInt amount,
  }) {
    return AirdropFunded(
      airdropId: airdropId,
      amount: amount,
    );
  }

  Claimed claimed({
    required int airdropId,
    required _i3.AccountId32 account,
    required BigInt amount,
  }) {
    return Claimed(
      airdropId: airdropId,
      account: account,
      amount: amount,
    );
  }

  AirdropDeleted airdropDeleted({required int airdropId}) {
    return AirdropDeleted(airdropId: airdropId);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return AirdropCreated._decode(input);
      case 1:
        return AirdropFunded._decode(input);
      case 2:
        return Claimed._decode(input);
      case 3:
        return AirdropDeleted._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Event value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case AirdropCreated:
        (value as AirdropCreated).encodeTo(output);
        break;
      case AirdropFunded:
        (value as AirdropFunded).encodeTo(output);
        break;
      case Claimed:
        (value as Claimed).encodeTo(output);
        break;
      case AirdropDeleted:
        (value as AirdropDeleted).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case AirdropCreated:
        return (value as AirdropCreated)._sizeHint();
      case AirdropFunded:
        return (value as AirdropFunded)._sizeHint();
      case Claimed:
        return (value as Claimed)._sizeHint();
      case AirdropDeleted:
        return (value as AirdropDeleted)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A new airdrop has been created.
///
/// Parameters: [airdrop_id, merkle_root]
class AirdropCreated extends Event {
  const AirdropCreated({
    required this.airdropId,
    required this.merkleRoot,
  });

  factory AirdropCreated._decode(_i1.Input input) {
    return AirdropCreated(
      airdropId: _i1.U32Codec.codec.decode(input),
      merkleRoot: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// AirdropId
  /// The ID of the created airdrop
  final int airdropId;

  /// MerkleRoot
  /// The Merkle root of the airdrop
  final List<int> merkleRoot;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'AirdropCreated': {
          'airdropId': airdropId,
          'merkleRoot': merkleRoot.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(airdropId);
    size = size + const _i1.U8ArrayCodec(32).sizeHint(merkleRoot);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      airdropId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      merkleRoot,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AirdropCreated &&
          other.airdropId == airdropId &&
          _i4.listsEqual(
            other.merkleRoot,
            merkleRoot,
          );

  @override
  int get hashCode => Object.hash(
        airdropId,
        merkleRoot,
      );
}

/// An airdrop has been funded with tokens.
///
/// Parameters: [airdrop_id, amount]
class AirdropFunded extends Event {
  const AirdropFunded({
    required this.airdropId,
    required this.amount,
  });

  factory AirdropFunded._decode(_i1.Input input) {
    return AirdropFunded(
      airdropId: _i1.U32Codec.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// AirdropId
  /// The ID of the funded airdrop
  final int airdropId;

  /// <<T as Config>::Currency as Inspect<T::AccountId>>::Balance
  /// The amount of tokens added to the airdrop
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'AirdropFunded': {
          'airdropId': airdropId,
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(airdropId);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      airdropId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AirdropFunded &&
          other.airdropId == airdropId &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        airdropId,
        amount,
      );
}

/// A user has claimed tokens from an airdrop.
///
/// Parameters: [airdrop_id, account, amount]
class Claimed extends Event {
  const Claimed({
    required this.airdropId,
    required this.account,
    required this.amount,
  });

  factory Claimed._decode(_i1.Input input) {
    return Claimed(
      airdropId: _i1.U32Codec.codec.decode(input),
      account: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// AirdropId
  /// The ID of the airdrop claimed from
  final int airdropId;

  /// T::AccountId
  /// The account that claimed the tokens
  final _i3.AccountId32 account;

  /// <<T as Config>::Currency as Inspect<T::AccountId>>::Balance
  /// The amount of tokens claimed
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Claimed': {
          'airdropId': airdropId,
          'account': account.toList(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(airdropId);
    size = size + const _i3.AccountId32Codec().sizeHint(account);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      airdropId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      account,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Claimed &&
          other.airdropId == airdropId &&
          _i4.listsEqual(
            other.account,
            account,
          ) &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        airdropId,
        account,
        amount,
      );
}

/// An airdrop has been deleted.
///
/// Parameters: [airdrop_id]
class AirdropDeleted extends Event {
  const AirdropDeleted({required this.airdropId});

  factory AirdropDeleted._decode(_i1.Input input) {
    return AirdropDeleted(airdropId: _i1.U32Codec.codec.decode(input));
  }

  /// AirdropId
  /// The ID of the deleted airdrop
  final int airdropId;

  @override
  Map<String, Map<String, int>> toJson() => {
        'AirdropDeleted': {'airdropId': airdropId}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(airdropId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      airdropId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AirdropDeleted && other.airdropId == airdropId;

  @override
  int get hashCode => airdropId.hashCode;
}
