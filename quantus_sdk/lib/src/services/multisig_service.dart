import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' show Txs;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_create_submission.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/rust/api/multisig.dart' as multisig_rust;
import 'package:quantus_sdk/src/services/multisig_graphql.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';

class MultisigService {
  static final MultisigService _instance = MultisigService._internal();
  factory MultisigService() => _instance;
  MultisigService._internal();

  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();
  final SubstrateService _substrateService = SubstrateService();

  static const int _avgBlockTimeSeconds = 12;
  static const int _dummyCurrentBlock = 1500000;
  static final BigInt defaultMultisigNonce = BigInt.zero;

  /// Suggested approval threshold at roughly 70% of [signerCount].
  static int defaultThreshold(int signerCount) {
    if (signerCount <= 0) return 1;
    final threshold = (signerCount * 0.7).round();
    final minThreshold = signerCount >= 2 ? 2 : 1;
    return threshold.clamp(minThreshold, signerCount);
  }

  Future<List<MultisigAccount>> discoverForUser(List<String> myAccountIds) async {
    if (myAccountIds.isEmpty) return [];

    final data = await _postGraphQl({'query': MultisigGraphql.buildDiscoverQuery(myAccountIds)});
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
  /// [isAddressTaken] returns true (defaults to [isMultisigOnChain]).
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
    final taken = isAddressTaken ?? isMultisigOnChain;
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
  Future<bool> isMultisigOnChain(String address) async {
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
    final signersRaw = record['signers'];
    final signers = signersRaw is List ? signersRaw.map((e) => e.toString()).toList() : <String>[];

    final rawThreshold = record['threshold'] as int?;
    final threshold = rawThreshold != null && rawThreshold >= 1 ? rawThreshold : 1;

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

  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) async {
    debugPrint('[MultisigService] getOpenProposals stub: ${msig.accountId}');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _dummyOpenProposals(msig);
  }

  Future<List<MultisigProposal>> getPastProposals(MultisigAccount msig) async {
    debugPrint('[MultisigService] getPastProposals stub: ${msig.accountId}');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _dummyPastProposals(msig);
  }

  Future<MultisigProposal?> getProposal(MultisigAccount msig, int id) async {
    debugPrint('[MultisigService] getProposal stub: ${msig.accountId} #$id');
    final open = await getOpenProposals(msig);
    for (final p in open) {
      if (p.id == id) return p;
    }
    final past = await getPastProposals(msig);
    for (final p in past) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<int> currentBlockNumber() async {
    return _dummyCurrentBlock;
  }

  Future<BigInt> estimateProposeFee(MultisigAccount msig, String recipient, BigInt amount) async {
    debugPrint('[MultisigService] estimateProposeFee stub');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return BigInt.parse('1500000000000');
  }

  Future<BigInt> estimateApproveFee(MultisigAccount msig, int proposalId) async {
    debugPrint('[MultisigService] estimateApproveFee stub');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return BigInt.parse('250000000000');
  }

  Future<int> propose({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
  }) async {
    debugPrint('[MultisigService] propose stub: ${msig.accountId} -> $recipient amount=$amount');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return 99;
  }

  Future<void> approve({required MultisigAccount msig, required Account signer, required int proposalId}) async {
    debugPrint('[MultisigService] approve stub: ${msig.accountId} #$proposalId');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> cancel({required MultisigAccount msig, required Account signer, required int proposalId}) async {
    debugPrint('[MultisigService] cancel stub: ${msig.accountId} #$proposalId');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  DateTime blockToTime(int blockNumber) {
    final deltaBlocks = blockNumber - _dummyCurrentBlock;
    return DateTime.now().add(Duration(seconds: deltaBlocks * _avgBlockTimeSeconds));
  }

  int timeToBlock(DateTime when) {
    final deltaSeconds = when.difference(DateTime.now()).inSeconds;
    return _dummyCurrentBlock + (deltaSeconds ~/ _avgBlockTimeSeconds);
  }

  List<MultisigProposal> _dummyOpenProposals(MultisigAccount msig) {
    final now = DateTime.now();
    final mePending = msig.myMemberAccountId;
    final other = msig.signers.firstWhere((s) => s != mePending, orElse: () => mePending);
    return [
      MultisigProposal(
        id: 12,
        multisigAddress: msig.accountId,
        proposer: other,
        amount: BigInt.parse('10000000000000000'),
        recipient: '5DfhGyQdFobKM8NsWvEeAKk5EQQgYe9AydgJ7rMB6E1EqRzV',
        expiryBlock: _dummyCurrentBlock + 7200,
        expiryAt: now.add(const Duration(days: 1)),
        approvals: [other],
        deposit: BigInt.parse('1000000000000'),
        fee: BigInt.parse('1500000000000'),
        status: MultisigProposalStatus.active,
        threshold: msig.threshold,
        signerCount: msig.signers.length,
      ),
      MultisigProposal(
        id: 13,
        multisigAddress: msig.accountId,
        proposer: mePending,
        amount: BigInt.parse('500000000000000'),
        recipient: '5HGjWAeFDfFCWPsjFQdVV2Msvz2XtMktvgocEZcCj68kUMaw',
        expiryBlock: _dummyCurrentBlock + 14400,
        expiryAt: now.add(const Duration(days: 2)),
        approvals: [mePending],
        deposit: BigInt.parse('1000000000000'),
        fee: BigInt.parse('1500000000000'),
        status: MultisigProposalStatus.active,
        threshold: msig.threshold,
        signerCount: msig.signers.length,
      ),
    ];
  }

  List<MultisigProposal> _dummyPastProposals(MultisigAccount msig) {
    final now = DateTime.now();
    final me = msig.myMemberAccountId;
    final other = msig.signers.firstWhere((s) => s != me, orElse: () => me);
    return [
      MultisigProposal(
        id: 11,
        multisigAddress: msig.accountId,
        proposer: me,
        amount: BigInt.parse('25000000000000000'),
        recipient: '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty',
        expiryBlock: _dummyCurrentBlock - 100,
        expiryAt: now.subtract(const Duration(days: 1)),
        approvals: msig.signers.take(msig.threshold).toList(),
        deposit: BigInt.parse('1000000000000'),
        fee: BigInt.parse('1500000000000'),
        status: MultisigProposalStatus.executed,
        threshold: msig.threshold,
        signerCount: msig.signers.length,
      ),
      MultisigProposal(
        id: 10,
        multisigAddress: msig.accountId,
        proposer: other,
        amount: BigInt.parse('1500000000000000'),
        recipient: '5DAAnrj7VHTznn2AWBemMuyBwZWs6FNFjdyVXUeYum3PTXFy',
        expiryBlock: _dummyCurrentBlock - 5000,
        expiryAt: now.subtract(const Duration(days: 5)),
        approvals: [other],
        deposit: BigInt.parse('1000000000000'),
        fee: BigInt.parse('1500000000000'),
        status: MultisigProposalStatus.expired,
        threshold: msig.threshold,
        signerCount: msig.signers.length,
      ),
      MultisigProposal(
        id: 9,
        multisigAddress: msig.accountId,
        proposer: me,
        amount: BigInt.parse('800000000000000'),
        recipient: '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY',
        expiryBlock: _dummyCurrentBlock - 7000,
        expiryAt: now.subtract(const Duration(days: 7)),
        approvals: [me],
        deposit: BigInt.parse('1000000000000'),
        fee: BigInt.parse('1500000000000'),
        status: MultisigProposalStatus.cancelled,
        threshold: msig.threshold,
        signerCount: msig.signers.length,
      ),
    ];
  }
}
