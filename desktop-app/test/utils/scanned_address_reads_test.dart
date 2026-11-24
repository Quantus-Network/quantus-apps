import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/utils/scanned_address_reads.dart';

const _first = 'qzFirstAddress';
const _second = 'qzSecondAddress';
const _taken = 'qzTakenAddress';

ScannedAddressReads _reads() =>
    ScannedAddressReads(isValidAddress: (text) => text.startsWith('qz'), isInApp: (address) => address == _taken);

void main() {
  test('three identical reads confirm the address', () {
    final reads = _reads();

    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadConfirmed>().having((read) => read.address, 'address', _first));
  });

  test('a different address starts the count again', () {
    final reads = _reads();

    reads.add(_first);
    reads.add(_first);
    expect(reads.add(_second), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadConfirmed>());
  });

  test('a code that is not an address says so and starts the count again', () {
    final reads = _reads();

    reads.add(_first);
    reads.add(_first);
    expect(reads.add('https://example.com'), isA<ReadNotAnAddress>());
    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadConfirmed>());
  });

  test('an address already in the app is refused and starts the count again', () {
    final reads = _reads();

    reads.add(_first);
    reads.add(_first);
    expect(reads.add(_taken), isA<ReadAlreadyInApp>());
    expect(reads.add(_first), isA<ReadPending>());
  });

  test('surrounding whitespace is not part of the address', () {
    final reads = _reads();

    reads.add('$_first\n');
    reads.add(' $_first');
    expect(reads.add(_first), isA<ReadConfirmed>().having((read) => read.address, 'address', _first));
  });

  test('after a confirmed address, three new reads are needed', () {
    final reads = _reads();

    reads.add(_first);
    reads.add(_first);
    reads.add(_first);

    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadPending>());
    expect(reads.add(_first), isA<ReadConfirmed>());
  });

  test('reset forgets the reads so far', () {
    final reads = _reads();

    reads.add(_first);
    reads.add(_first);
    reads.reset();

    expect(reads.add(_first), isA<ReadPending>());
  });
}
