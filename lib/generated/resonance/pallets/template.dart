// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'dart:typed_data' as _i4;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/pallet_template/pallet/call.dart' as _i6;
import '../types/resonance_runtime/runtime_call.dart' as _i5;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<int> _something = const _i1.StorageValue<int>(
    prefix: 'Template',
    storage: 'Something',
    valueCodec: _i2.U32Codec.codec,
  );

  /// A storage item for this pallet.
  ///
  /// In this template, we are declaring a storage item called `Something` that stores a single
  /// `u32` value. Learn more about runtime storage here: <https://docs.substrate.io/build/runtime-storage/>
  _i3.Future<int?> something({_i1.BlockHash? at}) async {
    final hashedKey = _something.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _something.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Returns the storage key for `something`.
  _i4.Uint8List somethingKey() {
    final hashedKey = _something.hashedKey();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// An example dispatchable that takes a single u32 value as a parameter, writes the value
  /// to storage and emits an event.
  ///
  /// It checks that the _origin_ for this call is _Signed_ and returns a dispatch
  /// error if it isn't. Learn more about origins here: <https://docs.substrate.io/build/origins/>
  _i5.Template doSomething({required int something}) {
    return _i5.Template(_i6.DoSomething(something: something));
  }

  /// An example dispatchable that may throw a custom error.
  ///
  /// It checks that the caller is a signed origin and reads the current value from the
  /// `Something` storage item. If a current value exists, it is incremented by 1 and then
  /// written back to storage.
  ///
  /// ## Errors
  ///
  /// The function will return an error under the following conditions:
  ///
  /// - If no value has been set ([`Error::NoneValue`])
  /// - If incrementing the value in storage causes an arithmetic overflow
  ///  ([`Error::StorageOverflow`])
  _i5.Template causeError() {
    return _i5.Template(_i6.CauseError());
  }
}
