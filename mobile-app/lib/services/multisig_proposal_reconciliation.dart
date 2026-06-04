import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';

/// Refreshes proposal-related state after a proposal is confirmed on-chain.
void reconcileConfirmedProposal(Ref ref, MultisigAccount msig) {
  ref.invalidate(multisigProposalsProvider(msig));
  ref.invalidate(multisigCurrentBlockProvider);
}
