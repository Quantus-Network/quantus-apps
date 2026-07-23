import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart' show Provider;
import 'package:polkadart/scale_codec.dart' as scale;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' show Constants, Txs;
import 'package:quantus_sdk/generated/planck/planck.dart' show Planck;
import 'package:quantus_sdk/generated/planck/types/pallet_balances/pallet/call.dart' as balances_call;
import 'package:quantus_sdk/generated/planck/types/pallet_reversible_transfers/pallet/call.dart' as reversible_call;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_create_submission.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/propose_fee_breakdown.dart';
import 'package:quantus_sdk/src/rust/api/multisig.dart' as multisig_rust;
import 'package:quantus_sdk/src/services/balances_service.dart';
import 'package:quantus_sdk/src/services/multisig_graphql.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';

class MultisigService {
  static final MultisigService _instance = MultisigService._internal();
  factory MultisigService() => _instance;
  MultisigService._internal();

  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();
  final RpcEndpointService _rpcEndpointService = RpcEndpointService();
  final SubstrateService _substrateService = SubstrateService();
  static final Constants palletConstants = Constants();

  static const Duration defaultProposalExpiry = Duration(days: 2);
  static final BigInt defaultMultisigNonce = BigInt.zero;

  /// Non-refundable fee burned when creating a proposal.
  BigInt get proposalFee => palletConstants.proposalFee;

  /// Refundable deposit reserved while a proposal is open.
  BigInt get proposalDeposit => palletConstants.proposalDeposit;

  /// Suggested approval threshold at roughly 70% of [signerCount].
  static int defaultThreshold(int signerCount) {
    if (signerCount <= 0) return 1;
    return (signerCount * 2 / 3).round().clamp(1, signerCount);
  }

  Future<List<MultisigAccount>> discoverForUser(List<String> myAccountIds) async {
    if (myAccountIds.isEmpty) return [];

    final data = await _postGraphQl({
      'query': MultisigGraphql.discoverQuery,
      'variables': MultisigGraphql.buildDiscoverVariables(myAccountIds),
    });
    final records = parseMultisigDiscoverData(data);
    final seen = <String>{};
    final results = <MultisigAccount>[];
    var index = 0;

    for (final record in records) {
      final address = stringFromJson(record['id']);
      if (!seen.add(address)) continue;

      final myMember = resolveMyMemberAccountId(record, myAccountIds);
      if (myMember == null) continue;

      index++;
      results.add(multisigAccountFromIndexerRecord(record, myMemberAccountId: myMember, name: 'Multisig $index'));
    }

    return results;
  }

  /// Predicts the on-chain multisig address for the given signers and threshold.
  ///
  /// Uses [nonce] for address uniqueness; defaults to [defaultMultisigNonce].
  Future<String> predictMultisigAddress({required List<String> signers, required int threshold, BigInt? nonce}) async {
    _validateSignersAndThreshold(signers, threshold, minSigners: 1);

    return multisig_rust.predictMultisigAddress(
      signers: signers,
      threshold: threshold,
      nonce: nonce ?? defaultMultisigNonce,
    );
  }

  /// Finds the lowest [nonce] whose predicted address is not taken.
  ///
  /// An address is taken when it appears in [reservedAddresses] or
  /// [isAddressTaken] returns true (defaults to [isMultisigIndexed]).
  Future<MultisigCreationParams> resolveMultisigCreationParams({
    required List<String> signers,
    required int threshold,
    Set<String> reservedAddresses = const {},
    BigInt? startNonce,
    Future<bool> Function(String address)? isAddressTaken,
    Future<String> Function({required List<String> signers, required int threshold, required BigInt nonce})?
    predictAddress,
    int maxAttempts = 64,
  }) async {
    final predict =
        predictAddress ??
        (({required signers, required threshold, required nonce}) =>
            predictMultisigAddress(signers: signers, threshold: threshold, nonce: nonce));
    final taken = isAddressTaken ?? isMultisigIndexed;
    var nonce = startNonce ?? defaultMultisigNonce;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final address = await predict(signers: signers, threshold: threshold, nonce: nonce);
      if (!reservedAddresses.contains(address) && !await taken(address)) {
        return MultisigCreationParams(nonce: nonce, address: address);
      }
      nonce += BigInt.one;
    }

    throw MultisigNonceExhaustedException(maxAttempts: maxAttempts);
  }

  /// Builds the runtime call for `multisig.create_multisig`.
  Multisig buildCreateMultisigCall({required List<String> signers, required int threshold, required BigInt nonce}) {
    _validateSignersAndThreshold(signers, threshold, minSigners: 2);
    final signerIds = signers.map(getAccountId32).toList();
    return const Txs().createMultisig(signers: signerIds, threshold: threshold, nonce: nonce);
  }

  /// Returns whether a multisig at [address] is present in the GraphQL indexer.
  Future<bool> isMultisigIndexed(String address) async {
    final record = await fetchMultisigFromIndexer(address);
    return record != null;
  }

  /// Fetches multisig metadata from the indexer by primary key ([address]).
  Future<Map<String, dynamic>?> fetchMultisigFromIndexer(String address) async {
    final data = await _postGraphQl({
      'query': MultisigGraphql.byPkQuery,
      'variables': {'id': address},
    });
    return parseMultisigByPkData(data);
  }

  /// Submits `create_multisig` signed by [creator]. Returns the extrinsic hash bytes.
  Future<Uint8List> submitCreateMultisigExtrinsic({
    required Account creator,
    required List<String> signers,
    required int threshold,
    BigInt? nonce,
  }) async {
    final effectiveNonce = nonce ?? defaultMultisigNonce;
    final call = buildCreateMultisigCall(signers: signers, threshold: threshold, nonce: effectiveNonce);
    return _substrateService.submitExtrinsic(creator, call);
  }

  /// Parses `multisig_by_pk` from a GraphQL `data` payload. Exported for tests.
  static Map<String, dynamic>? parseMultisigByPkData(Map<String, dynamic>? data) {
    final record = data?['multisig_by_pk'];
    if (record is! Map<String, dynamic>) return null;
    return record;
  }

  /// Parses `multisig` list from a discover-query `data` payload.
  static List<Map<String, dynamic>> parseMultisigDiscoverData(Map<String, dynamic>? data) {
    final raw = data?['multisig'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Maps an indexer multisig record to a local [MultisigAccount].
  static MultisigAccount multisigAccountFromIndexerRecord(
    Map<String, dynamic> record, {
    required String myMemberAccountId,
    required String name,
  }) {
    final address = stringFromJson(record['id']);
    final creator = nestedAccountId(record['creator']);
    final signers = nonEmptyStringListFromJson(record['signers'], 'signers');
    final threshold = multisigThresholdFromJson(record['threshold'], signerCount: signers.length);

    return MultisigAccount(
      name: name,
      accountId: address,
      signers: signers,
      threshold: threshold,
      nonce: bigIntFromJson(record['nonce']),
      myMemberAccountId: myMemberAccountId,
      creator: creator.isEmpty ? null : creator,
    );
  }

  /// First [myAccountIds] entry that appears in indexer [record] signers.
  static String? resolveMyMemberAccountId(Map<String, dynamic> record, List<String> myAccountIds) {
    final signersRaw = record['signers'];
    if (signersRaw is! List) return null;
    final signers = signersRaw.map((e) => e.toString()).toSet();
    for (final id in myAccountIds) {
      if (signers.contains(id)) return id;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _postGraphQl(Map<String, dynamic> requestBody) async {
    final response = await _graphQlEndpointService.post(body: jsonEncode(requestBody));

    if (response.statusCode != 200) {
      throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    return responseBody['data'] as Map<String, dynamic>?;
  }

  /// Validates [signers] and [threshold] for multisig operations.
  ///
  /// [minSigners] is the minimum signer count for the operation: prediction
  /// allows a single signer, while on-chain creation requires at least two.
  /// The threshold must be between 1 and the number of signers.
  void _validateSignersAndThreshold(List<String> signers, int threshold, {required int minSigners}) {
    if (signers.length < minSigners) {
      throw ArgumentError.value(signers, 'signers', 'At least $minSigners signer(s) are required');
    }
    if (threshold < 1 || threshold > signers.length) {
      throw ArgumentError.value(threshold, 'threshold', 'Must be between 1 and ${signers.length}');
    }
  }

  /// Proposals with active or approved status.
  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) {
    return _fetchProposals(
      msig,
      query: MultisigProposalGraphql.openProposalsQuery,
      variables: MultisigProposalGraphql.buildOpenProposalsVariables(msig.accountId),
    );
  }

  /// Proposals with executed, cancelled, or removed status.
  Future<List<MultisigProposal>> getPastProposals(MultisigAccount msig) {
    return _fetchProposals(
      msig,
      query: MultisigProposalGraphql.pastProposalsQuery,
      variables: MultisigProposalGraphql.buildPastProposalsVariables(msig.accountId),
    );
  }

  Future<List<MultisigProposal>> _fetchProposals(
    MultisigAccount msig, {
    required String query,
    required Map<String, dynamic> variables,
  }) async {
    final requestBody = {'query': query, 'variables': variables};
    final response = await _graphQlEndpointService.post(body: jsonEncode(requestBody));

    if (response.statusCode != 200) {
      throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final rows = (responseBody['data'] as Map<String, dynamic>?)?['multisig_proposal'];
    if (rows is! List) return [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) => MultisigProposal.fromIndexerJson(row, msig: msig))
        .toList();
  }

  Future<MultisigProposal?> getProposal(MultisigAccount msig, int id) async {
    final requestBody = {
      'query': MultisigProposalGraphql.proposalQuery,
      'variables': MultisigProposalGraphql.buildProposalVariables(msig.accountId, id),
    };
    final response = await _graphQlEndpointService.post(body: jsonEncode(requestBody));

    if (response.statusCode != 200) {
      throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final rows = (responseBody['data'] as Map<String, dynamic>?)?['multisig_proposal'];
    if (rows is! List || rows.isEmpty) return null;
    final first = rows.first;
    if (first is! Map<String, dynamic>) return null;
    return MultisigProposal.fromIndexerJson(first, msig: msig);
  }

  Future<int> currentBlockNumber() => _substrateService.getCurrentBlockNumber();

  BigInt proposalCreationFee(int signerCount) => MultisigProposal.proposalCreationFeeFor(signerCount);

  /// Estimates all fee components for creating a transfer proposal.
  Future<ProposeFeeBreakdown> estimateProposeFeeBreakdown({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
  }) async {
    final currentBlock = await currentBlockNumber();
    final expiryBlock = currentBlock + blocksForDuration(defaultProposalExpiry);
    final call = buildProposeTransferCall(msig: msig, recipient: recipient, amount: amount, expiryBlock: expiryBlock);
    final feeData = await _substrateService.getFeeForCall(signer, call);
    return ProposeFeeBreakdown(
      networkFee: feeData.fee,
      deposit: proposalDeposit,
      creationFee: proposalCreationFee(msig.signers.length),
      expiryBlock: expiryBlock,
    );
  }

  /// Estimates the total member cost of creating a transfer proposal.
  Future<BigInt> estimateProposeFee({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
  }) async {
    final breakdown = await estimateProposeFeeBreakdown(
      msig: msig,
      signer: signer,
      recipient: recipient,
      amount: amount,
    );
    return breakdown.memberCost;
  }

  /// Builds the `multisig.propose` runtime call wrapping a
  /// `balances.transfer_allow_death` from [msig] to [recipient].
  RuntimeCall buildProposeTransferCall({
    required MultisigAccount msig,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
  }) {
    final innerCall = BalancesService().getBalanceTransferCall(recipient, amount);
    final callBytes = innerCall.encode();
    return const Txs().propose(multisigAddress: getAccountId32(msig.accountId), call: callBytes, expiry: expiryBlock);
  }

  /// Submits a transfer proposal signed by [signer] (a member of [msig]).
  ///
  /// Returns the extrinsic hash bytes. The on-chain proposal id is not known
  /// until the proposal is indexed.
  Future<Uint8List> propose({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
  }) async {
    final call = buildProposeTransferCall(msig: msig, recipient: recipient, amount: amount, expiryBlock: expiryBlock);
    return _substrateService.submitExtrinsic(signer, call);
  }

  /// Loads the authoritative proposal call bytes from on-chain
  /// `Multisig.Proposals(multisig, proposalId)` storage.
  ///
  /// The indexer only describes proposals; this is the source of truth the
  /// chain executes. Returns null when the proposal is not in storage
  /// (executed, cancelled, or never proposed).
  Future<Uint8List?> getOnChainProposalCall({required MultisigAccount msig, required int proposalId}) async {
    return _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      final api = Planck(provider);
      final proposal = await api.query.multisig.proposals(getAccountId32(msig.accountId), proposalId);
      if (proposal == null) return null;
      return Uint8List.fromList(proposal.call);
    });
  }

  /// Decodes [callBytes] as a balance send (balances transfer or reversible
  /// schedule transfer), returning the recipient and amount.
  ///
  /// Returns null when the call is not a recognized send; callers should fall
  /// back to displaying the raw call bytes.
  static ({String recipient, BigInt amount})? decodeTransferCall(List<int> callBytes) {
    try {
      final input = scale.ByteInput(Uint8List.fromList(callBytes));
      final call = RuntimeCall.decode(input);

      multi_address.MultiAddress? dest;
      BigInt? amount;
      if (call is Balances) {
        final inner = call.value0;
        if (inner is balances_call.TransferAllowDeath) {
          dest = inner.dest;
          amount = inner.value;
        } else if (inner is balances_call.TransferKeepAlive) {
          dest = inner.dest;
          amount = inner.value;
        }
      } else if (call is ReversibleTransfers) {
        final inner = call.value0;
        if (inner is reversible_call.ScheduleTransfer) {
          dest = inner.dest;
          amount = inner.amount;
        } else if (inner is reversible_call.ScheduleTransferWithDelay) {
          dest = inner.dest;
          amount = inner.amount;
        }
      }

      if (dest is multi_address.Id && amount != null) {
        final recipient = AddressExtension.ss58AddressFromBytes(Uint8List.fromList(dest.value0));
        return (recipient: recipient, amount: amount);
      }
    } catch (e) {
      debugPrint('[MultisigService] Failed to decode on-chain proposal call: $e');
    }
    return null;
  }

  /// Builds the `multisig.approve` runtime call for [proposalId].
  ///
  /// [call] must be the proposal's inner call bytes as stored on-chain (see
  /// [getOnChainProposalCall]); the pallet rejects approvals whose call is not
  /// byte-equal to the stored payload (`CallMismatch`).
  Multisig buildApproveCall({required MultisigAccount msig, required int proposalId, required List<int> call}) {
    return const Txs().approve(multisigAddress: getAccountId32(msig.accountId), proposalId: proposalId, call: call);
  }

  /// Estimates the network fee for approving [proposalId].
  Future<BigInt> estimateApproveFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    required List<int> call,
  }) async {
    final runtimeCall = buildApproveCall(msig: msig, proposalId: proposalId, call: call);
    final feeData = await _substrateService.getFeeForCall(signer, runtimeCall);
    return feeData.fee;
  }

  /// Submits `multisig.approve` signed by [signer]. Returns extrinsic hash bytes.
  Future<Uint8List> submitApproveExtrinsic({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    required List<int> call,
  }) async {
    final runtimeCall = buildApproveCall(msig: msig, proposalId: proposalId, call: call);
    return _substrateService.submitExtrinsic(signer, runtimeCall);
  }

  /// Builds the `multisig.execute` runtime call for [proposalId].
  Multisig buildExecuteCall({required MultisigAccount msig, required int proposalId}) {
    return const Txs().execute(multisigAddress: getAccountId32(msig.accountId), proposalId: proposalId);
  }

  /// Estimates the network fee for executing [proposalId].
  Future<BigInt> estimateExecuteFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
  }) async {
    final call = buildExecuteCall(msig: msig, proposalId: proposalId);
    final feeData = await _substrateService.getFeeForCall(signer, call);
    return feeData.fee;
  }

  /// Submits `multisig.execute` signed by [signer]. Returns extrinsic hash bytes.
  Future<Uint8List> submitExecuteExtrinsic({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
  }) async {
    final call = buildExecuteCall(msig: msig, proposalId: proposalId);
    return _substrateService.submitExtrinsic(signer, call);
  }

  /// Builds the `multisig.cancel` runtime call for [proposalId].
  Multisig buildCancelCall({required MultisigAccount msig, required int proposalId}) {
    return const Txs().cancel(multisigAddress: getAccountId32(msig.accountId), proposalId: proposalId);
  }

  /// Estimates the network fee for cancelling [proposalId].
  Future<BigInt> estimateCancelFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
  }) async {
    final call = buildCancelCall(msig: msig, proposalId: proposalId);
    final feeData = await _substrateService.getFeeForCall(signer, call);
    return feeData.fee;
  }

  /// Submits `multisig.cancel` signed by [signer]. Returns extrinsic hash bytes.
  Future<Uint8List> submitCancelExtrinsic({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
  }) async {
    final call = buildCancelCall(msig: msig, proposalId: proposalId);
    return _substrateService.submitExtrinsic(signer, call);
  }

  /// Number of blocks that approximately span [duration] at average block time.
  int blocksForDuration(Duration duration) {
    return (duration.inSeconds / AppConstants.avgBlockTimeSeconds).round();
  }

  /// Approximate wall-clock time at which [targetBlock] is reached, given the
  /// known [currentBlock].
  DateTime blockToTime(int targetBlock, int currentBlock) {
    final deltaBlocks = targetBlock - currentBlock;
    return DateTime.now().add(Duration(seconds: deltaBlocks * AppConstants.avgBlockTimeSeconds));
  }
}
