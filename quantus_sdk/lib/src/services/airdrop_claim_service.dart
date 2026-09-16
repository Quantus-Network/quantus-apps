import 'dart:convert';

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
  /// signed expiry stays inside the server's window. Stops at the first
  /// rejected claim.
  Future<void> submitClaims({
    required List<AirdropMatch> matches,
    required String mnemonic,
    required String claimAccount,
  }) async {
    final claimable = {for (final m in matches.where((m) => m.claimable)) m.address: m}.values;
    if (claimable.isEmpty) throw Exception('None of the matched addresses can be claimed');
    for (final match in claimable) {
      final body = await _claimBody(match, mnemonic: mnemonic, claimAccount: claimAccount);
      final response = await _client.post(
        _claimEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception('Claim for ${match.address} rejected (${response.statusCode}): ${_serverError(response)}');
      }
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
