// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i1;

typedef U512 = List<BigInt>;

class U512Codec with _i1.Codec<U512> {
  const U512Codec();

  @override
  U512 decode(_i1.Input input) {
    return const _i1.U64ArrayCodec(8).decode(input);
  }

  @override
  void encodeTo(
    U512 value,
    _i1.Output output,
  ) {
    const _i1.U64ArrayCodec(8).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(U512 value) {
    return const _i1.U64ArrayCodec(8).sizeHint(value);
  }
}
