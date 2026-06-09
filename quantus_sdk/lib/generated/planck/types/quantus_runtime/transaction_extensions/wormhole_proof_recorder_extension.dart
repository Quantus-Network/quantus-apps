// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i1;

typedef WormholeProofRecorderExtension = dynamic;

class WormholeProofRecorderExtensionCodec
    with _i1.Codec<WormholeProofRecorderExtension> {
  const WormholeProofRecorderExtensionCodec();

  @override
  WormholeProofRecorderExtension decode(_i1.Input input) {
    return _i1.NullCodec.codec.decode(input);
  }

  @override
  void encodeTo(
    WormholeProofRecorderExtension value,
    _i1.Output output,
  ) {
    _i1.NullCodec.codec.encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(WormholeProofRecorderExtension value) {
    return _i1.NullCodec.codec.sizeHint(value);
  }
}
