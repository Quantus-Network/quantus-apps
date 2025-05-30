// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i6;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i7;

import '../../polkadot_parachain_primitives/primitives/id.dart' as _i2;
import '../../polkadot_parachain_primitives/primitives/validation_code_hash.dart'
    as _i5;
import '../../primitive_types/h256.dart' as _i3;
import 'internal_version.dart' as _i4;

class CandidateDescriptorV2 {
  const CandidateDescriptorV2({
    required this.paraId,
    required this.relayParent,
    required this.version,
    required this.coreIndex,
    required this.sessionIndex,
    required this.reserved1,
    required this.persistedValidationDataHash,
    required this.povHash,
    required this.erasureRoot,
    required this.reserved2,
    required this.paraHead,
    required this.validationCodeHash,
  });

  factory CandidateDescriptorV2.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// ParaId
  final _i2.Id paraId;

  /// H
  final _i3.H256 relayParent;

  /// InternalVersion
  final _i4.InternalVersion version;

  /// u16
  final int coreIndex;

  /// SessionIndex
  final int sessionIndex;

  /// [u8; 25]
  final List<int> reserved1;

  /// Hash
  final _i3.H256 persistedValidationDataHash;

  /// Hash
  final _i3.H256 povHash;

  /// Hash
  final _i3.H256 erasureRoot;

  /// [u8; 64]
  final List<int> reserved2;

  /// Hash
  final _i3.H256 paraHead;

  /// ValidationCodeHash
  final _i5.ValidationCodeHash validationCodeHash;

  static const $CandidateDescriptorV2Codec codec =
      $CandidateDescriptorV2Codec();

  _i6.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'paraId': paraId,
        'relayParent': relayParent.toList(),
        'version': version,
        'coreIndex': coreIndex,
        'sessionIndex': sessionIndex,
        'reserved1': reserved1.toList(),
        'persistedValidationDataHash': persistedValidationDataHash.toList(),
        'povHash': povHash.toList(),
        'erasureRoot': erasureRoot.toList(),
        'reserved2': reserved2.toList(),
        'paraHead': paraHead.toList(),
        'validationCodeHash': validationCodeHash.toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CandidateDescriptorV2 &&
          other.paraId == paraId &&
          _i7.listsEqual(
            other.relayParent,
            relayParent,
          ) &&
          other.version == version &&
          other.coreIndex == coreIndex &&
          other.sessionIndex == sessionIndex &&
          _i7.listsEqual(
            other.reserved1,
            reserved1,
          ) &&
          _i7.listsEqual(
            other.persistedValidationDataHash,
            persistedValidationDataHash,
          ) &&
          _i7.listsEqual(
            other.povHash,
            povHash,
          ) &&
          _i7.listsEqual(
            other.erasureRoot,
            erasureRoot,
          ) &&
          _i7.listsEqual(
            other.reserved2,
            reserved2,
          ) &&
          _i7.listsEqual(
            other.paraHead,
            paraHead,
          ) &&
          other.validationCodeHash == validationCodeHash;

  @override
  int get hashCode => Object.hash(
        paraId,
        relayParent,
        version,
        coreIndex,
        sessionIndex,
        reserved1,
        persistedValidationDataHash,
        povHash,
        erasureRoot,
        reserved2,
        paraHead,
        validationCodeHash,
      );
}

class $CandidateDescriptorV2Codec with _i1.Codec<CandidateDescriptorV2> {
  const $CandidateDescriptorV2Codec();

  @override
  void encodeTo(
    CandidateDescriptorV2 obj,
    _i1.Output output,
  ) {
    _i1.U32Codec.codec.encodeTo(
      obj.paraId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.relayParent,
      output,
    );
    _i1.U8Codec.codec.encodeTo(
      obj.version,
      output,
    );
    _i1.U16Codec.codec.encodeTo(
      obj.coreIndex,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      obj.sessionIndex,
      output,
    );
    const _i1.U8ArrayCodec(25).encodeTo(
      obj.reserved1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.persistedValidationDataHash,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.povHash,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.erasureRoot,
      output,
    );
    const _i1.U8ArrayCodec(64).encodeTo(
      obj.reserved2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.paraHead,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.validationCodeHash,
      output,
    );
  }

  @override
  CandidateDescriptorV2 decode(_i1.Input input) {
    return CandidateDescriptorV2(
      paraId: _i1.U32Codec.codec.decode(input),
      relayParent: const _i1.U8ArrayCodec(32).decode(input),
      version: _i1.U8Codec.codec.decode(input),
      coreIndex: _i1.U16Codec.codec.decode(input),
      sessionIndex: _i1.U32Codec.codec.decode(input),
      reserved1: const _i1.U8ArrayCodec(25).decode(input),
      persistedValidationDataHash: const _i1.U8ArrayCodec(32).decode(input),
      povHash: const _i1.U8ArrayCodec(32).decode(input),
      erasureRoot: const _i1.U8ArrayCodec(32).decode(input),
      reserved2: const _i1.U8ArrayCodec(64).decode(input),
      paraHead: const _i1.U8ArrayCodec(32).decode(input),
      validationCodeHash: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  @override
  int sizeHint(CandidateDescriptorV2 obj) {
    int size = 0;
    size = size + const _i2.IdCodec().sizeHint(obj.paraId);
    size = size + const _i3.H256Codec().sizeHint(obj.relayParent);
    size = size + const _i4.InternalVersionCodec().sizeHint(obj.version);
    size = size + _i1.U16Codec.codec.sizeHint(obj.coreIndex);
    size = size + _i1.U32Codec.codec.sizeHint(obj.sessionIndex);
    size = size + const _i1.U8ArrayCodec(25).sizeHint(obj.reserved1);
    size =
        size + const _i3.H256Codec().sizeHint(obj.persistedValidationDataHash);
    size = size + const _i3.H256Codec().sizeHint(obj.povHash);
    size = size + const _i3.H256Codec().sizeHint(obj.erasureRoot);
    size = size + const _i1.U8ArrayCodec(64).sizeHint(obj.reserved2);
    size = size + const _i3.H256Codec().sizeHint(obj.paraHead);
    size = size +
        const _i5.ValidationCodeHashCodec().sizeHint(obj.validationCodeHash);
    return size;
  }
}
