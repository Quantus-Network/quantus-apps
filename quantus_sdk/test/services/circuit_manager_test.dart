import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:quantus_sdk/src/services/circuit_manager.dart';

void main() {
  test('versioned directory isolates each circuit release', () {
    expect(
      CircuitManager.getVersionedCircuitDirectory('/circuits', version: '4.2.0'),
      path.join('/circuits', 'v4.2.0'),
    );
  });

  test('circuit config requires a positive batch shape', () {
    expect(CircuitManager.parseShape('{"num_leaf_proofs":10,"num_exit_slots":32}'), (
      numLeafProofs: 10,
      numExitSlots: 32,
    ));
    expect(() => CircuitManager.parseShape('{}'), throwsFormatException);
    expect(() => CircuitManager.parseShape('{"num_leaf_proofs":7}'), throwsFormatException);
    expect(() => CircuitManager.parseShape('{"num_leaf_proofs":0,"num_exit_slots":32}'), throwsFormatException);
    expect(() => CircuitManager.parseShape('{"num_leaf_proofs":10,"num_exit_slots":0}'), throwsFormatException);
    expect(() => CircuitManager.parseShape('[]'), throwsFormatException);
  });
}
