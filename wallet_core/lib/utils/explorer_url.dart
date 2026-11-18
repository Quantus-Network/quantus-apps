import 'package:quantus_sdk/quantus_sdk.dart';

/// The block explorer's page for [path], e.g. `transactions/<hash>`.
String explorerUrl(String path) => '${AppConstants.explorerEndpoint}/$path';
