import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/reversible_transfers.dart' as reversible_pallet;
import 'package:quantus_sdk/generated/planck/pallets/tech_collective.dart' as collective_pallet;
import 'package:quantus_sdk/generated/planck/types/qp_scheduler/block_number_or_timestamp.dart' as qp;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';

/// Sample signing payloads for exercising the scan → review → sign flow on a
/// simulator, where there is no camera to scan a real QR with.
///
/// These are byte-identical in shape to what the hot wallet produces: a SCALE
/// `RuntimeCall` followed by the signed extensions, exactly as
/// `QuantusSigningPayload.encodeRaw` emits. Only reachable behind [kDebugMode]
/// from the scanner screen.
class DebugPayloads {
  const DebugPayloads._();

  /// Every payload the debug buttons offer, keyed by button label — one per
  /// distinct screen the signer can be shown, so each headline, hero and row
  /// combination can be eyeballed without a hot wallet.
  static final Map<String, Uint8List Function()> all = {
    'Send': transfer,
    'Reversible': reversibleTransfer,
    'Reversible 8h': reversibleTransferWithDelay,
    'Msig approve': multisigApproveTransfer,
    'Msig propose': multisigProposeTransfer,
    'Vote aye': governanceVoteAye,
  };

  /// A plain transfer — the everyday case. Headline: SEND.
  static Uint8List transfer() {
    return withExtensions(_send(BigInt.from(1500000000000))); // 1.5 tokens
  }

  /// A reversible transfer on the account's default window.
  /// Headline: REVERSIBLE SEND.
  static Uint8List reversibleTransfer() {
    return withExtensions(
      const reversible_pallet.Txs().scheduleTransfer(
        dest: _address(AppConstants.debugTestAddress),
        amount: BigInt.from(3000000000000), // 3 tokens
      ),
    );
  }

  /// A reversible transfer with an explicit one-off window, so the Delay row
  /// shows a real timeframe instead of the account default.
  static Uint8List reversibleTransferWithDelay() {
    return withExtensions(
      const reversible_pallet.Txs().scheduleTransferWithDelay(
        dest: _address(AppConstants.debugTestAddress),
        amount: BigInt.from(750000000000), // 0.75 tokens
        delay: qp.BlockNumberOrTimestamp.values.timestamp(BigInt.from(28800000)), // 8 hours
      ),
    );
  }

  /// A multisig approval carrying the transfer it authorises, so the review
  /// screen has a nested call to expand and an amount to lift into the hero.
  static Uint8List multisigApproveTransfer() {
    final inner = _send(BigInt.from(4200000000000)); // 4.2 tokens
    return withExtensions(
      const multisig_pallet.Txs().approve(multisigAddress: _debugMultisigAccount, proposalId: 12, call: inner.encode()),
    );
  }

  /// A new multisig proposal wrapping a transfer — same shape as the approval
  /// but labelled `You are proposing`, with an expiry instead of a proposal id.
  static Uint8List multisigProposeTransfer() {
    final inner = _send(BigInt.from(900000000000)); // 0.9 tokens
    return withExtensions(
      const multisig_pallet.Txs().propose(
        multisigAddress: _debugMultisigAccount,
        call: inner.encode(),
        expiry: 5000000,
      ),
    );
  }

  /// An aye vote on a tech-collective referendum — the governance path a core dev
  /// uses to enact a runtime upgrade. Moves no value, so the review screen must
  /// name the call instead of showing an amount.
  static Uint8List governanceVoteAye() {
    return withExtensions(const collective_pallet.Txs().vote(poll: 7, aye: true));
  }

  static RuntimeCall _send(BigInt value) =>
      const balances_pallet.Txs().transferAllowDeath(dest: _address(AppConstants.debugTestAddress), value: value);

  /// Synthetic multisig account; renders as a valid ss58 address with a
  /// checkphrase without needing a real on-chain multisig.
  static final Uint8List _debugMultisigAccount = Uint8List.fromList(List.filled(32, 0xA7));

  static multi_address.MultiAddress _address(String ss58) =>
      multi_address.MultiAddress.values.id(ss58ToAccountId(s: ss58));

  /// Appends the signed extensions the runtime expects, using the spec and
  /// transaction versions this build's metadata was generated from — so these
  /// payloads do not trip the spec-drift warning.
  /// The debug account the scanner injects for, matching the vault's first
  /// account so the signer screen can resolve it.
  static String debugSigner = AppConstants.debugTestAddress;

  static Uint8List withExtensions(RuntimeCall call) {
    return SigningRequest(signer: debugSigner, payload: _payload(call)).encode();
  }

  static Uint8List _payload(RuntimeCall call) {
    final out = ByteOutput();
    out.write(call.encode());
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
