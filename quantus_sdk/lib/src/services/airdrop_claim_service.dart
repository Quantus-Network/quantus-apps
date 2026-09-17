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

/// Some addresses could not be submitted: the server now holds [submitted] of
/// [total], and [causes] says what stopped each of the others. Submitting
/// again retries all of them; the ones already held answer 409 and count.
class AirdropClaimFailure implements Exception {
  final int submitted;
  final int total;
  final Map<String, Object> causes;

  const AirdropClaimFailure({required this.submitted, required this.total, required this.causes});

  @override
  String toString() => 'Claims submitted for $submitted of $total addresses; failed: $causes';
}

/// Client for the airdrop-claim server (Quantus-Network/airdrop-claim). Proves
/// ownership of snapshot addresses the wallet matched and records the claims;
/// only signatures and proofs leave the process, never a key or secret.
class AirdropClaimService {
  final http.Client _client;
  final Uri _claimEndpoint;
  final DilithiumClaimBuilder _buildDilithiumClaim;
  final WormholeClaimProver _proveWormhole;

  AirdropClaimService({
    http.Client? client,
    String endpoint = AppConstants.miningRewardsClaimEndpoint,
    DilithiumClaimBuilder? buildDilithiumClaim,
    WormholeClaimProver? proveWormhole,
  }) : _client = client ?? http.Client(),
       _claimEndpoint = Uri.parse('$endpoint/claim'),
       _buildDilithiumClaim = buildDilithiumClaim ?? buildAirdropDilithiumClaimFromMnemonic,
       _proveWormhole = proveWormhole ?? proveAirdropWormhole;

  /// Proves and submits one claim per claimable address in [matches], paid out
  /// to [claimAccount]. Each proof is built right before its request so the
  /// signed expiry stays inside the server's window. The server keeps one row
  /// per address and answers a repeat with 409, which counts as submitted, so
  /// the whole batch can simply be sent again until every address is held.
  /// Throws an [AirdropClaimFailure] once every address has been tried.
  Future<void> submitClaims({
    required List<AirdropMatch> matches,
    required String mnemonic,
    required String claimAccount,
  }) async {
    final claimable = {for (final m in matches.where((m) => m.claimable)) m.address: m}.values.toList();
    if (claimable.isEmpty) throw Exception('None of the matched addresses can be claimed');
    final causes = <String, Object>{};
    for (final match in claimable) {
      try {
        final body = await _claimBody(match, mnemonic: mnemonic, claimAccount: claimAccount);
        final response = await _client.post(
          _claimEndpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (response.statusCode != 200 && response.statusCode != HttpStatus.conflict) {
          throw Exception('Rejected (${response.statusCode}): ${_serverError(response)}');
        }
      } catch (e) {
        causes[match.address] = e;
      }
    }
    if (causes.isNotEmpty) {
      throw AirdropClaimFailure(submitted: claimable.length - causes.length, total: claimable.length, causes: causes);
    }
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
