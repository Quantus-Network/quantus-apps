import 'package:quantus_sdk/quantus_sdk.dart';

/// Block-explorer URL for an immediate (single-signer) transfer extrinsic.
String explorerImmediateTransactionUrl(String extrinsicHash) =>
    '${AppConstants.explorerEndpoint}/immediate-transactions/$extrinsicHash';
