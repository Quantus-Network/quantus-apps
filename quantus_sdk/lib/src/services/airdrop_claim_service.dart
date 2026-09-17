import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';

typedef DilithiumClaimBuilder =
    Future<DilithiumClaimBody> Function({
      required String mnemonic,
      required String dilithiumKeygen,
      required String address,
      required String claimAccount,
    });
typedef WormholeClaimProver =
    Future<WormholeClaimBody> Function({required List<int> wormholeSecret, required String claimAccount});

/// A batch that stopped: the server holds [recorded] of [total] addresses for
/// this payout address, and [cause] is what stopped the next one. When the
/// cause is an [AirdropClaimTaken], the rest cannot go to this payout address.
class AirdropClaimFailure implements Exception {
  final int recorded;
  final int total;
  final Object cause;

  const AirdropClaimFailure({required this.recorded, required this.total, required this.cause});

  @override
  String toString() => 'Claim batch stopped after $recorded of $total: $cause';
}

/// The server already holds [address] for a different payout address.
class AirdropClaimTaken implements Exception {
  final String address;
  final String recordedTo;

  const AirdropClaimTaken({required this.address, required this.recordedTo});

  @override
  String toString() => '$address is already claimed to $recordedTo';
}

/// Client for the airdrop-claim server (Quantus-Network/airdrop-claim). Proves
/// ownership of snapshot addresses the wallet matched and records the claims;
/// only signatures and proofs leave the process, never a key or secret.
class AirdropClaimService {
  final http.Client _client;
  final Uri _claimEndpoint;
  final Uri _unpaidEndpoint;
  final DilithiumClaimBuilder _buildDilithiumClaim;
  final WormholeClaimProver _proveWormhole;

  AirdropClaimService({
    http.Client? client,
    String endpoint = AppConstants.miningRewardsClaimEndpoint,
    DilithiumClaimBuilder? buildDilithiumClaim,
    WormholeClaimProver? proveWormhole,
  }) : _client = client ?? http.Client(),
       _claimEndpoint = Uri.parse('$endpoint/claim'),
       _unpaidEndpoint = Uri.parse('$endpoint/unpaid'),
       _buildDilithiumClaim = buildDilithiumClaim ?? buildAirdropDilithiumClaimFromMnemonic,
       _proveWormhole = proveWormhole ?? proveAirdropWormhole;

  /// Proves and submits one claim per claimable address in [matches], paid out
  /// to [claimAccount]. Each proof is built right before its request so the
  /// signed expiry stays inside the server's window. The server keeps one row
  /// per address, so an address it already holds counts as done only when the
  /// payout address it recorded is this one; a retry after a partial failure
  /// therefore finishes the missing addresses and never splits the payout.
  /// Throws an [AirdropClaimFailure] carrying how far the batch got.
  Future<void> submitClaims({
    required List<AirdropMatch> matches,
    required String mnemonic,
    required String claimAccount,
  }) async {
    final claimable = {for (final m in matches.where((m) => m.claimable)) m.address: m}.values.toList();
    if (claimable.isEmpty) throw Exception('None of the matched addresses can be claimed');
    Map<String, String?>? recordedTo;
    var recorded = 0;
    for (final match in claimable) {
      try {
        final body = await _claimBody(match, mnemonic: mnemonic, claimAccount: claimAccount);
        final response = await _client.post(
          _claimEndpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (response.statusCode == HttpStatus.conflict) {
          recordedTo ??= await _recordedDestinations();
          final existing = recordedTo[match.address];
          if (existing != null && existing != claimAccount) {
            throw AirdropClaimTaken(address: match.address, recordedTo: existing);
          }
        } else if (response.statusCode != 200) {
          throw Exception('Claim for ${match.address} rejected (${response.statusCode}): ${_serverError(response)}');
        }
      } catch (e) {
        throw AirdropClaimFailure(recorded: recorded, total: claimable.length, cause: e);
      }
      recorded++;
    }
  }

  /// Payout address the server holds for each recorded, not yet paid address.
  /// An address missing here was never claimed or is already paid out.
  Future<Map<String, String?>> _recordedDestinations() async {
    final response = await _client.get(_unpaidEndpoint);
    if (response.statusCode != 200) {
      throw Exception('Unpaid claims request failed (${response.statusCode}): ${_serverError(response)}');
    }
    final rows = (jsonDecode(response.body) as Map<String, dynamic>)['rows'] as List<dynamic>;
    return {for (final row in rows) row['address'] as String: row['claim_account'] as String?};
  }

  /// The server answers every rejection with `{"error": "..."}`.
  static String _serverError(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map<String, dynamic>)['error'] as String;
    } on FormatException {
      return response.body;
    } on TypeError {
      return response.body;
    }
  }

  Future<Map<String, Object>> _claimBody(
    AirdropMatch match, {
    required String mnemonic,
    required String claimAccount,
  }) async {
    switch (match.kind) {
      case 'dilithium':
        final claim = await _buildDilithiumClaim(
          mnemonic: mnemonic,
          dilithiumKeygen: match.dilithiumKeygen!,
          address: match.address,
          claimAccount: claimAccount,
        );
        return {
          'kind': 'dilithium',
          'scheme': claim.scheme,
          'address': claim.address,
          'claim_account': claim.claimAccount,
          'public_key': claim.publicKeyHex,
          'signature': claim.signatureHex,
          'expiry_unix': claim.expiryUnix,
        };
      case 'wormhole':
        final claim = await _proveWormhole(wormholeSecret: match.wormholeSecret!, claimAccount: claimAccount);
        return {'kind': 'wormhole', 'proof_kind': claim.proofKind, 'proof': claim.proofHex};
      default:
        throw StateError('Unknown airdrop match kind: ${match.kind}');
    }
  }
}
