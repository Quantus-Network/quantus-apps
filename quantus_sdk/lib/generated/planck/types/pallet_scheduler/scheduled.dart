// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../frame_support/traits/preimages/bounded.dart' as _i2;
import '../quantus_runtime/origin_caller.dart' as _i3;

class Scheduled {
  const Scheduled({this.maybeId, required this.priority, required this.call, required this.origin});

  factory Scheduled.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// Option<Name>
  final List<int>? maybeId;

  /// schedule::Priority
  final int priority;

  /// Call
  final _i2.Bounded call;

  /// PalletsOrigin
  final _i3.OriginCaller origin;

  static const $ScheduledCodec codec = $ScheduledCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
    'maybeId': maybeId?.toList(),
    'priority': priority,
    'call': call.toJson(),
    'origin': origin.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Scheduled &&
          other.maybeId == maybeId &&
          other.priority == priority &&
          other.call == call &&
          other.origin == origin;

  @override
  int get hashCode => Object.hash(maybeId, priority, call, origin);
}

class $ScheduledCodec with _i1.Codec<Scheduled> {
  const $ScheduledCodec();

  @override
  void encodeTo(Scheduled obj, _i1.Output output) {
    const _i1.OptionCodec<List<int>>(_i1.U8ArrayCodec(32)).encodeTo(obj.maybeId, output);
    _i1.U8Codec.codec.encodeTo(obj.priority, output);
    _i2.Bounded.codec.encodeTo(obj.call, output);
    _i3.OriginCaller.codec.encodeTo(obj.origin, output);
  }

  @override
  Scheduled decode(_i1.Input input) {
    return Scheduled(
      maybeId: const _i1.OptionCodec<List<int>>(_i1.U8ArrayCodec(32)).decode(input),
      priority: _i1.U8Codec.codec.decode(input),
      call: _i2.Bounded.codec.decode(input),
      origin: _i3.OriginCaller.codec.decode(input),
    );
  }

  @override
  int sizeHint(Scheduled obj) {
    int size = 0;
    size = size + const _i1.OptionCodec<List<int>>(_i1.U8ArrayCodec(32)).sizeHint(obj.maybeId);
    size = size + _i1.U8Codec.codec.sizeHint(obj.priority);
    size = size + _i2.Bounded.codec.sizeHint(obj.call);
    size = size + _i3.OriginCaller.codec.sizeHint(obj.origin);
    return size;
  }
}
