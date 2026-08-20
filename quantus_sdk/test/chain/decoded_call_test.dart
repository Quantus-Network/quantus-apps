import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  test('addresses lists unique ss58 values from nested calls and groups', () {
    final inner = DecodedCall(
      pallet: 'Balances',
      call: 'transfer_allow_death',
      fields: [
        const ValueField('Destination', 'qzDest', kind: ValueKind.address),
        AmountField('Amount', BigInt.one),
      ],
    );
    final call = DecodedCall(
      pallet: 'Utility',
      call: 'batch',
      fields: [
        FieldGroup('Calls', [NestedCallField('Call 0', inner)]),
        const ValueField('Origin', 'qzDest', kind: ValueKind.address),
        const ValueField('Other', 'qzOther', kind: ValueKind.address),
        const ValueField('Hash', '0xabc', kind: ValueKind.hash),
      ],
    );

    expect(call.addresses, ['qzDest', 'qzOther']);
  });

  test('addresses is empty when no address fields are present', () {
    const call = DecodedCall(
      pallet: 'System',
      call: 'remark',
      fields: [ValueField('Remark', 'hello', kind: ValueKind.text)],
    );

    expect(call.addresses, isEmpty);
  });
}
