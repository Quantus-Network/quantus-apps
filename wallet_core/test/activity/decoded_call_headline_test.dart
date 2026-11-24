import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/decoded_call_headline.dart';

const _recipient = 'qzW6mKe1RtZ8pLc3YhNv5DxQa9SgFb2UoJi7Vn4kTw3sHd';

String _amountText(BigInt token) => '$token QTC';

void main() {
  test('a transfer is headed by its amount, with the recipient shortened under it', () {
    final call = DecodedCall(
      pallet: 'Balances',
      call: 'transfer_keep_alive',
      fields: const [],
      summary: TransferSummary(amount: BigInt.from(250), recipient: _recipient),
    );

    final headline = DecodedCallHeadline.of(call, amountText: _amountText);

    expect(headline.primary, '250 QTC');
    expect(headline.recipient, AddressFormattingService.formatAddress(_recipient));
    expect(headline.palletSubtitle, isNull);
    expect(headline.secondary, headline.recipient);
  });

  test('a call that moves nothing is headed by its readable name, with its pallet under it', () {
    const call = DecodedCall(pallet: 'ReversibleTransfers', call: 'set_high_security', fields: []);

    final headline = DecodedCallHeadline.of(call, amountText: _amountText);

    expect(headline.primary, 'Set high security');
    expect(headline.recipient, isNull);
    expect(headline.palletSubtitle, 'ReversibleTransfers');
    expect(headline.secondary, 'ReversibleTransfers');
  });

  test('a call with no name is headed by its pallet alone', () {
    const call = DecodedCall(pallet: 'Utility', call: '', fields: []);

    final headline = DecodedCallHeadline.of(call, amountText: _amountText);

    expect(headline.primary, 'Utility');
    expect(headline.secondary, isNull);
  });

  test('an asset transfer names its asset instead of the native token', () {
    final call = DecodedCall(
      pallet: 'Assets',
      call: 'transfer',
      fields: const [],
      summary: TransferSummary(amount: BigInt.from(7), assetId: 3),
    );

    final headline = DecodedCallHeadline.of(call, amountText: _amountText);

    expect(headline.primary, '7 (asset #3)');
    expect(headline.secondary, isNull);
  });
}
