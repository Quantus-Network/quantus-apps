// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Event` enum of this pallet
enum Event {
  /// Batch of dispatches completed fully with no error.
  batchCompleted('BatchCompleted', 0),

  /// A single item within a Batch of dispatches has completed with no error.
  itemCompleted('ItemCompleted', 1);

  const Event(this.variantName, this.codecIndex);

  factory Event.decode(_i1.Input input) {
    return codec.decode(input);
  }

  final String variantName;

  final int codecIndex;

  static const $EventCodec codec = $EventCodec();

  String toJson() => variantName;
  _i2.Uint8List encode() {
    return codec.encode(this);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Event.batchCompleted;
      case 1:
        return Event.itemCompleted;
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Event value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
