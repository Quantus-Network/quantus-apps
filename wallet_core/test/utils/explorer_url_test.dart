import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/explorer_url.dart';

void main() {
  test('a page of the explorer is its path under the explorer\'s address', () {
    expect(explorerUrl('transactions/0xhash'), '${AppConstants.explorerEndpoint}/transactions/0xhash');
  });

  test('a transaction of a private send has its own kind of page, named by its hash', () {
    expect(wormholeExplorerUrl('0xproof'), '${AppConstants.explorerEndpoint}/transactions/wormhole/0xproof');
  });
}
