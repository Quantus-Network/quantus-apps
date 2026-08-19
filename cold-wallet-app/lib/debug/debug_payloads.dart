import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/recovery.dart' as recovery_pallet;
import 'package:quantus_sdk/generated/planck/pallets/tech_collective.dart' as collective_pallet;
import 'package:quantus_sdk/generated/planck/pallets/utility.dart' as utility_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
// ignore: implementation_imports — the generated corpus is test/debug data, deliberately not public SDK API.
import 'package:quantus_sdk/src/testing/call_corpus.dart';

/// One entry in the debug catalogue: a call the signer can be asked to review.
class DebugCall {
  /// Pallet name as the runtime declares it, e.g. `Balances`.
  final String pallet;

  /// Call name, with the corpus' variant suffix where it has one, e.g.
  /// `set_metadata [maybe_hash=Some]`.
  final String label;

  /// The SCALE-encoded `RuntimeCall`, ready to be wrapped in signed extensions.
  final Uint8List call;

  const DebugCall({required this.pallet, required this.label, required this.call});
}

/// Sample signing payloads for exercising the scan → review → sign flow on a
/// simulator, where there is no camera to scan a real QR with.
///
/// These are byte-identical in shape to what the hot wallet produces: a SCALE
/// `RuntimeCall` followed by the signed extensions, exactly as
/// `QuantusSigningPayload.encodeRaw` emits. Only reachable behind [kDebugMode]
/// from the scanner screen.
class DebugPayloads {
  const DebugPayloads._();

  /// Every call the debug list offers, grouped by pallet with Balances first.
  ///
  /// The bulk comes from the generated [callCorpus] — one encoding per call the
  /// runtime declares, plus one per enum-argument variant — so a runtime that
  /// gains a call gains a row here without anything being written by hand.
  static final Map<String, List<DebugCall>> byPallet = _grouped();

  static Map<String, List<DebugCall>> _grouped() {
    final grouped = <String, List<DebugCall>>{};
    final seen = <String>{};
    for (final call in [...callCorpus.entries.map(_fromCorpus), ..._composed]) {
      // The corpus repeats an identical encoding once per nested-call variant
      // (every `as_recovered [call=…]` is the same bytes); one row is enough.
      if (!seen.add(hex.encode(call.call))) continue;
      grouped.putIfAbsent(call.pallet, () => []).add(call);
    }

    final balances = grouped.remove('Balances');
    if (balances == null) throw StateError('The call corpus declares no Balances pallet');
    return {'Balances': balances, ...grouped};
  }

  static DebugCall _fromCorpus(MapEntry<String, String> entry) {
    final dot = entry.key.indexOf('.');
    if (dot < 0) throw StateError('Corpus key "${entry.key}" is not Pallet.call');
    return DebugCall(
      pallet: entry.key.substring(0, dot),
      label: entry.key.substring(dot + 1),
      call: Uint8List.fromList(hex.decode(entry.value)),
    );
  }

  /// The wrapper calls the corpus cannot express: it fills every nested call
  /// slot with the same three-byte `System.remark`, so the screens that lift an
  /// inner transfer into the hero position — a multisig proposal or approval, a
  /// batch, a recovered-account dispatch — are only reachable from here.
  static final List<DebugCall> _composed = [
    DebugCall(
      pallet: 'Multisig',
      label: 'propose [carrying a transfer]',
      call: const multisig_pallet.Txs()
          .propose(multisigAddress: _debugMultisigAccount, call: _send(_tokens(0.9)).encode(), expiry: 5000000)
          .encode(),
    ),
    DebugCall(
      pallet: 'Multisig',
      label: 'approve [carrying a transfer]',
      call: const multisig_pallet.Txs()
          .approve(multisigAddress: _debugMultisigAccount, proposalId: 12, call: _send(_tokens(4.2)).encode())
          .encode(),
    ),
    DebugCall(
      pallet: 'Utility',
      label: 'batch_all [two transfers]',
      call: const utility_pallet.Txs().batchAll(calls: [_send(_tokens(1.5)), _send(_tokens(0.25))]).encode(),
    ),
    DebugCall(pallet: 'Utility', label: 'batch_all [16 transfers]', call: _batchOf(16).encode()),
    DebugCall(
      pallet: 'Multisig',
      label: 'approve [batch_all of 16 transfers]',
      call: const multisig_pallet.Txs()
          .approve(multisigAddress: _debugMultisigAccount, proposalId: 12, call: _batchOf(16).encode())
          .encode(),
    ),
    DebugCall(
      pallet: 'Multisig',
      label: 'propose [batch_all of 16 transfers]',
      call: const multisig_pallet.Txs()
          .propose(multisigAddress: _debugMultisigAccount, call: _batchOf(16).encode(), expiry: 5000000)
          .encode(),
    ),
    DebugCall(
      pallet: 'Recovery',
      label: 'as_recovered [carrying a transfer]',
      call: const recovery_pallet.Txs()
          .asRecovered(account: _address(AppConstants.debugTestAddress), call: _send(_tokens(3)))
          .encode(),
    ),
  ];

  /// Shapes the signer refuses outright, so the fail-closed screen — the one a
  /// signer sees instead of a call it cannot read in full — is reachable too.
  ///
  /// Nesting stops at [maxCallNestingDepth] levels, and a batch may not carry
  /// another batch at any depth, so neither a ten-level chain nor a tree of
  /// batches inside multisigs inside batches can be built: the decoder refuses
  /// them before it reads an argument byte.
  static final List<DebugCall> refused = [
    DebugCall(pallet: 'Multisig', label: 'propose × 3 [one level past the limit]', call: _multisigChain(3).encode()),
    DebugCall(pallet: 'Multisig', label: 'propose × 10 [ten levels deep]', call: _multisigChain(10).encode()),
    DebugCall(
      pallet: 'Utility',
      label: 'batch_all inside a batch_all',
      call: const utility_pallet.Txs().batchAll(calls: [_innerBatch]).encode(),
    ),
    DebugCall(
      pallet: 'Utility',
      label: 'batch_all of multisigs carrying batch_alls',
      call: const utility_pallet.Txs()
          .batchAll(
            calls: [
              const multisig_pallet.Txs().propose(
                multisigAddress: _debugMultisigAccount,
                call: _innerBatch.encode(),
                expiry: 5000000,
              ),
            ],
          )
          .encode(),
    ),
  ];

  /// The batch every refused shape carries as its second batch.
  static final RuntimeCall _innerBatch = _batchOf(2);

  /// A batch of [count] transfers, each for a different amount so no two rows
  /// on the review screen are interchangeable.
  static RuntimeCall _batchOf(int count) =>
      const utility_pallet.Txs().batchAll(calls: [for (var i = 1; i <= count; i++) _send(_tokens(i / 4))]);

  /// [depth] multisig proposals, each carrying the next, innermost a transfer.
  static RuntimeCall _multisigChain(int depth) {
    var call = _send(_tokens(1.5));
    for (var i = 0; i < depth; i++) {
      call = const multisig_pallet.Txs().propose(
        multisigAddress: _debugMultisigAccount,
        call: call.encode(),
        expiry: 5000000,
      );
    }
    return call;
  }

  /// An aye vote on a tech-collective referendum — moves no value, so the review
  /// screen must name the call instead of showing an amount.
  static Uint8List governanceVoteAye() {
    return withExtensions(const collective_pallet.Txs().vote(poll: 7, aye: true));
  }

  static RuntimeCall _send(BigInt value) =>
      const balances_pallet.Txs().transferAllowDeath(dest: _address(AppConstants.debugTestAddress), value: value);

  static BigInt _tokens(double amount) => BigInt.from(amount * 1000000000000);

  /// Synthetic multisig account; renders as a valid ss58 address with a
  /// checkphrase without needing a real on-chain multisig.
  static final Uint8List _debugMultisigAccount = Uint8List.fromList(List.filled(32, 0xA7));

  /// Decoded in pure Dart rather than through the Rust bridge, so the catalogue
  /// can be built before — or without — [RustLib] being initialised.
  static multi_address.MultiAddress _address(String ss58) =>
      multi_address.MultiAddress.values.id(AddressExtension.accountIdFromSs58(ss58));

  /// The debug account the scanner injects for, matching the vault's first
  /// account so the signer screen can resolve it.
  static String debugSigner = AppConstants.debugTestAddress;

  static Uint8List withExtensions(RuntimeCall call) {
    return SigningRequest(signer: debugSigner, payload: _payload(call)).encode();
  }

  static Uint8List _payload(RuntimeCall call) => payloadForCall(call.encode());

  /// Appends the signed extensions the runtime expects, using the spec and
  /// transaction versions this build's metadata was generated from — so these
  /// payloads do not trip the spec-drift warning.
  static Uint8List payloadForCall(List<int> callBytes) {
    final out = ByteOutput();
    out.write(callBytes);
    out.write(const [0x55, 0x01]); // mortal era: period 64, phase 21
    CompactCodec.codec.encodeTo(0, out); // nonce
    CompactBigIntCodec.codec.encodeTo(BigInt.zero, out); // tip
    out.pushByte(0); // CheckMetadataHash mode: disabled
    U32Codec.codec.encodeTo(AppConstants.bundledSpecVersion, out);
    U32Codec.codec.encodeTo(AppConstants.bundledTransactionVersion, out);
    out.write(hex.decode(_planckGenesisHex));
    out.write(List.filled(32, 0x11)); // block hash (not validated by the signer)
    out.pushByte(0); // metadata hash: None
    return out.toBytes();
  }

  /// Read back from the signer's own network table, so these payloads stay valid
  /// if the Planck genesis hash there ever changes.
  static String get _planckGenesisHex => knownNetworks.entries.firstWhere((e) => e.value == 'Planck').key;
}
