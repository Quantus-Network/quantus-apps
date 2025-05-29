// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i4;

import 'polkadot_primitives/v8/core_index.dart' as _i2;
import 'polkadot_runtime_parachains/scheduler/pallet/paras_entry.dart' as _i3;
import 'tuples.dart' as _i1;

typedef BTreeMap = List<_i1.Tuple2<_i2.CoreIndex, List<_i3.ParasEntry>>>;

class BTreeMapCodec with _i4.Codec<BTreeMap> {
  const BTreeMapCodec();

  @override
  BTreeMap decode(_i4.Input input) {
    return const _i4
        .SequenceCodec<_i1.Tuple2<_i2.CoreIndex, List<_i3.ParasEntry>>>(
        _i1.Tuple2Codec<_i2.CoreIndex, List<_i3.ParasEntry>>(
      _i2.CoreIndexCodec(),
      _i4.SequenceCodec<_i3.ParasEntry>(_i3.ParasEntry.codec),
    )).decode(input);
  }

  @override
  void encodeTo(
    BTreeMap value,
    _i4.Output output,
  ) {
    const _i4.SequenceCodec<_i1.Tuple2<_i2.CoreIndex, List<_i3.ParasEntry>>>(
        _i1.Tuple2Codec<_i2.CoreIndex, List<_i3.ParasEntry>>(
      _i2.CoreIndexCodec(),
      _i4.SequenceCodec<_i3.ParasEntry>(_i3.ParasEntry.codec),
    )).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(BTreeMap value) {
    return const _i4
        .SequenceCodec<_i1.Tuple2<_i2.CoreIndex, List<_i3.ParasEntry>>>(
        _i1.Tuple2Codec<_i2.CoreIndex, List<_i3.ParasEntry>>(
      _i2.CoreIndexCodec(),
      _i4.SequenceCodec<_i3.ParasEntry>(_i3.ParasEntry.codec),
    )).sizeHint(value);
  }
}
