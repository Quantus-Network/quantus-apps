import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' show Txs;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/rust/api/multisig.dart' as multisig_rust;
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';

class MultisigService {
  static final MultisigService _instance = MultisigService._internal();
  factory MultisigService() => _instance;
  MultisigService._internal();

  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();
  final SubstrateService _substrateService = SubstrateService();

  static const String _multisigByPkQuery = r'''
    query MultisigByPk($id: String!) {
      multisig_by_pk(id: $id) {
        id
        timestamp
        threshold
        nonce
        signers
        creator {
          id
        }
        block {
          height
        }
        extrinsic {
          id
          pallet
          call
        }
      }
    }
  ''';

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
    debugPrint('[MultisigService] discoverForUser stub, my accounts: ${myAccountIds.length}');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (myAccountIds.isEmpty) return [];
    final me = myAccountIds.first;
    return _dummyMultisigs(me);
  }

  Future<MultisigAccount?> lookupByAddress(String address, List<String> myAccountIds) async {
    debugPrint('[MultisigService] lookupByAddress stub: $address');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (myAccountIds.isEmpty) {
      throw Exception('No local accounts; cannot determine member account');
    }
    final me = myAccountIds.first;
    return MultisigAccount(
      name: 'Multisig',
      accountId: address,
      signers: [
        me,
        _dummySigner('5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY'),
        _dummySigner('5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty'),
      ],
      threshold: 2,
      nonce: BigInt.from(42),
      myMemberAccountId: me,
      creator: me,
    );
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

  /// Builds the runtime call for `multisig.create_multisig`.
  Multisig buildCreateMultisigCall({required List<String> signers, required int threshold, required BigInt nonce}) {
    _validateSignersAndThreshold(signers, threshold, minSigners: 2);
    final signerIds = signers.map(getAccountId32).toList();
    return Txs().createMultisig(signers: signerIds, threshold: threshold, nonce: nonce);
  }

  /// Returns whether a multisig at [address] is present in the GraphQL indexer.
  Future<bool> isMultisigOnChain(String address) async {
    final record = await fetchMultisigFromIndexer(address);
    return record != null;
  }

  /// Fetches multisig metadata from the indexer by primary key ([address]).
  Future<Map<String, dynamic>?> fetchMultisigFromIndexer(String address) async {
    final requestBody = {
      'query': _multisigByPkQuery,
      'variables': {'id': address},
    };

    final response = await _graphQlEndpointService.post(body: jsonEncode(requestBody));

    if (response.statusCode != 200) {
      throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final data = responseBody['data'] as Map<String, dynamic>?;
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

  String _dummySigner(String fallback) => fallback;

  List<MultisigAccount> _dummyMultisigs(String me) {
    return [
      MultisigAccount(
        name: 'Treasury Multisig',
        accountId: '5MultisigTreasury000000000000000000000000000000000',
        signers: [
          me,
          '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY',
          '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty',
          '5DAAnrj7VHTznn2AWBemMuyBwZWs6FNFjdyVXUeYum3PTXFy',
          '5HGjWAeFDfFCWPsjFQdVV2Msvz2XtMktvgocEZcCj68kUMaw',
        ],
        threshold: 3,
        nonce: BigInt.from(1),
        myMemberAccountId: me,
        creator: me,
      ),
      MultisigAccount(
        name: 'Ops 2-of-3',
        accountId: '5MultisigOpsTeam0000000000000000000000000000000000',
        signers: [
          me,
          '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY',
          '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty',
        ],
        threshold: 2,
        nonce: BigInt.from(2),
        myMemberAccountId: me,
        creator: '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY',
      ),
    ];
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
