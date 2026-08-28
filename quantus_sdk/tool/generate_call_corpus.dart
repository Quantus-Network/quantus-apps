// Enumerates every call the bundled metadata declares and writes one synthesized
// SCALE encoding per call (plus one per enum-argument variant) to
// lib/src/testing/call_corpus.dart, so both wallets can assert their rendering
// against the whole runtime surface.
//
// Run from quantus_sdk after regenerating bindings:
//   dart run tool/generate_call_corpus.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:polkadart_scale_codec/polkadart_scale_codec.dart';
import 'package:substrate_metadata/substrate_metadata.dart';

late final Map<int, PortableType> types;

PortableType typeOf(int id) => types[id] ?? (throw StateError('metadata has no type $id'));

bool isRuntimeCall(PortableType t) => t.type.path.length >= 2 && t.type.path.last == 'RuntimeCall';

bool isU8(int id) {
  final def = typeOf(id).type.typeDef;
  return def is TypeDefPrimitive && def.primitive == Primitive.U8;
}

/// Three bytes that are simultaneously a decodable `System.remark([])` and a
/// plausible opaque blob, so a `Vec<u8>` that is really a call still decodes.
const leafCall = [0, 0, 0];

class Synth {
  final int argIndex;
  final int variantChoiceArg;
  final int variantChoice;

  /// True once this encoding selects an address form the wallets refuse.
  bool refused = false;

  Synth(this.argIndex, {this.variantChoiceArg = -1, this.variantChoice = 0});

  int _tag() => 0xA0 + (argIndex % 0x50);

  void write(int id, Output out, Set<int> seen) {
    final t = typeOf(id);
    if (isRuntimeCall(t)) {
      out.write(leafCall);
      return;
    }
    if (!seen.add(id)) throw StateError('recursive type ${t.type.path.join('::')} outside RuntimeCall');

    final def = t.type.typeDef;
    if (def is TypeDefComposite) {
      for (final f in def.fields) {
        write(f.type, out, seen);
      }
    } else if (def is TypeDefVariant) {
      if (def.variants.isEmpty) throw StateError('empty variant ${t.type.path.join('::')}');
      final pick = (argIndex == variantChoiceArg) ? variantChoice % def.variants.length : 0;
      final v = def.variants[pick];
      if (t.type.path.last == 'MultiAddress' && v.name != 'Id') refused = true;
      out.pushByte(v.index);
      for (final f in v.fields) {
        write(f.type, out, seen);
      }
    } else if (def is TypeDefSequence) {
      if (isU8(def.type)) {
        out.write(leafCall.length.toRadixString(2).isEmpty ? [] : []);
        CompactCodec.codec.encodeTo(leafCall.length, out);
        out.write(leafCall);
      } else {
        CompactCodec.codec.encodeTo(1, out);
        write(def.type, out, seen);
      }
    } else if (def is TypeDefArray) {
      if (isU8(def.type)) {
        out.write(List.filled(def.length, _tag()));
      } else {
        for (var i = 0; i < def.length; i++) {
          write(def.type, out, seen);
        }
      }
    } else if (def is TypeDefTuple) {
      for (final f in def.fields) {
        write(f, out, seen);
      }
    } else if (def is TypeDefPrimitive) {
      writePrimitive(def.primitive, out);
    } else if (def is TypeDefCompact) {
      writeCompact(def.type, out);
    } else if (def is TypeDefBitSequence) {
      CompactCodec.codec.encodeTo(0, out);
    } else {
      throw StateError('unhandled type def ${def.runtimeType}');
    }
    seen.remove(id);
  }

  void writePrimitive(Primitive p, Output out) {
    switch (p) {
      case Primitive.Bool:
        out.pushByte(1);
      case Primitive.U8:
        out.pushByte(7);
      case Primitive.I8:
        out.pushByte(7);
      case Primitive.U16:
      case Primitive.I16:
        U16Codec.codec.encodeTo(4242, out);
      case Primitive.U32:
      case Primitive.I32:
        U32Codec.codec.encodeTo(1000003 + argIndex, out);
      case Primitive.U64:
      case Primitive.I64:
        U64Codec.codec.encodeTo(BigInt.from(1500000000000), out);
      case Primitive.U128:
      case Primitive.I128:
        U128Codec.codec.encodeTo(BigInt.from(1500000000000), out);
      case Primitive.U256:
      case Primitive.I256:
        out.write(List.filled(32, 0));
      case Primitive.Str:
        final bytes = 'quantus arg $argIndex'.codeUnits;
        CompactCodec.codec.encodeTo(bytes.length, out);
        out.write(bytes);
      case Primitive.Char:
        throw StateError('char is not expected in a call argument');
    }
  }

  void writeCompact(int inner, Output out) {
    var id = inner;
    while (true) {
      final def = typeOf(id).type.typeDef;
      if (def is TypeDefPrimitive) {
        if (def.primitive == Primitive.U128 || def.primitive == Primitive.U64) {
          CompactBigIntCodec.codec.encodeTo(BigInt.from(1500000000000), out);
        } else {
          CompactCodec.codec.encodeTo(1000003, out);
        }
        return;
      }
      if (def is TypeDefTuple && def.fields.isEmpty) return; // Compact<()> is zero bytes
      if (def is TypeDefComposite && def.fields.length == 1) {
        id = def.fields.first.type;
        continue;
      }
      throw StateError('unsupported Compact inner type $id');
    }
  }
}

void main() {
  final blob = File('test/fixtures/planck_metadata.scale').readAsBytesSync();
  final metadata = RuntimeMetadataPrefixed.fromBytes(blob).metadata;
  types = {for (final t in metadata.types) t.id: t};

  final entries = <String, String>{};
  final refused = <String, String>{};

  for (final pallet in metadata.pallets) {
    final calls = pallet.calls;
    if (calls == null) continue;
    final def = typeOf(calls.type).type.typeDef;
    if (def is! TypeDefVariant) continue;

    for (final variant in def.variants) {
      final argCount = variant.fields.length;

      // The default shape, plus one case per variant of each enum argument, so
      // every branch the describers have is exercised without the product of
      // all arguments.
      final cases = <({String suffix, int arg, int choice})>[(suffix: '', arg: -1, choice: 0)];
      for (var i = 0; i < argCount; i++) {
        final fieldDef = typeOf(variant.fields[i].type).type.typeDef;
        if (fieldDef is TypeDefVariant && fieldDef.variants.length > 1) {
          for (var c = 1; c < fieldDef.variants.length; c++) {
            cases.add((suffix: ' [${variant.fields[i].name ?? 'arg$i'}=${fieldDef.variants[c].name}]', arg: i, choice: c));
          }
        }
      }

      for (final c in cases) {
        final out = ByteOutput();
        out.pushByte(pallet.index);
        out.pushByte(variant.index);
        var ok = true;
        var isRefused = false;
        for (var i = 0; i < argCount; i++) {
          final synth = Synth(i, variantChoiceArg: c.arg, variantChoice: c.choice);
          try {
            synth.write(variant.fields[i].type, out, {});
          } catch (e) {
            stderr.writeln('skip ${pallet.name}.${variant.name}${c.suffix}: $e');
            ok = false;
            break;
          }
          isRefused = isRefused || synth.refused;
        }
        if (!ok) continue;
        final key = '${pallet.name}.${variant.name}${c.suffix}';
        (isRefused ? refused : entries)[key] = _hex(out.toBytes());
      }
    }
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED by tool/generate_call_corpus.dart - do not edit by hand.')
    ..writeln('//')
    ..writeln('// One synthesized SCALE encoding per call the runtime declares, plus one per')
    ..writeln('// variant of each enum argument. Regenerate after changing the bindings.')
    ..writeln('library;')
    ..writeln()
    ..writeln('const Map<String, String> callCorpus = {');
  for (final e in entries.entries) {
    buffer.writeln("  '${e.key}': '${e.value}',");
  }
  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// Encodings naming an address form this runtime cannot resolve, which both')
    ..writeln('/// wallets refuse rather than display.')
    ..writeln('const Map<String, String> refusedCallCorpus = {');
  for (final e in refused.entries) {
    buffer.writeln("  '${e.key}': '${e.value}',");
  }
  buffer.writeln('};');

  File('lib/src/testing/call_corpus.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('wrote ${entries.length} entries and ${refused.length} refused');
}

String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
