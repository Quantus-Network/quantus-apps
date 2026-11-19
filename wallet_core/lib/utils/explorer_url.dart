import 'package:quantus_sdk/quantus_sdk.dart';

/// The block explorer's page for [path], e.g. `transactions/<hash>`.
String explorerUrl(String path) => '${AppConstants.explorerEndpoint}/$path';

/// The explorer's page of one transaction of a private send, by the hash of
/// its extrinsic. A private send is one such transaction per batch of inputs.
String wormholeExplorerUrl(String extrinsicHash) => explorerUrl('transactions/wormhole/$extrinsicHash');
