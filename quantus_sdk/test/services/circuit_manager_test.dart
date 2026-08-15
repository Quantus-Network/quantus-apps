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

  test('circuit config requires a positive aggregation arity', () {
    expect(CircuitManager.parseNumLeafProofs('{"num_leaf_proofs":7}'), 7);
    expect(() => CircuitManager.parseNumLeafProofs('{}'), throwsFormatException);
    expect(() => CircuitManager.parseNumLeafProofs('{"num_leaf_proofs":0}'), throwsFormatException);
    expect(() => CircuitManager.parseNumLeafProofs('[]'), throwsFormatException);
  });
}
