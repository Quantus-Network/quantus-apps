// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// Events that functions in this pallet can emit.
///
/// Events are a simple means of indicating to the outside world (such as dApps, chain explorers
/// or other users) that some notable update in the runtime has occurred. In a FRAME pallet, the
/// documentation for each event field and its parameters is added to a node's metadata so it
/// can be used by external interfaces or tools.
///
/// 	The `generate_deposit` macro generates a function on `Pallet` called `deposit_event` which
/// will convert the event type of your pallet into `RuntimeEvent` (declared in the pallet's
/// [`Config`] trait) and deposit it using [`frame_system::Pallet::deposit_event`].
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

  SomethingStored somethingStored({
    required int something,
    required _i3.AccountId32 who,
  }) {
    return SomethingStored(
      something: something,
      who: who,
    );
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return SomethingStored._decode(input);
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
      case SomethingStored:
        (value as SomethingStored).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case SomethingStored:
        return (value as SomethingStored)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A user has successfully set a new value.
class SomethingStored extends Event {
  const SomethingStored({
    required this.something,
    required this.who,
  });

  factory SomethingStored._decode(_i1.Input input) {
    return SomethingStored(
      something: _i1.U32Codec.codec.decode(input),
      who: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// u32
  /// The new value set.
  final int something;

  /// T::AccountId
  /// The account who set the new value.
  final _i3.AccountId32 who;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'SomethingStored': {
          'something': something,
          'who': who.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(something);
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      something,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is SomethingStored &&
          other.something == something &&
          _i4.listsEqual(
            other.who,
            who,
          );

  @override
  int get hashCode => Object.hash(
        something,
        who,
      );
}
