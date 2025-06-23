library;

export 'src/services/substrate_service.dart';
export 'src/services/reversible_transfers_service.dart';
export 'src/services/recovery_service.dart';
export 'src/extensions/color_extensions.dart';
export 'src/services/settings_service.dart';
export 'src/constants/app_constants.dart';
export 'src/services/human_readable_checksum_service.dart';
export 'src/services/number_formatting_service.dart';
export 'src/models/transaction_model.dart';
export 'src/services/chain_history_service.dart';
export 'src/extensions/keypair_extensions.dart';
// note we have to hide some things here because they're exported by substrate service
// should probably expise all of crypto.dart through substrateservice instead TODO...
export 'src/rust/api/crypto.dart' hide crystalAlice, crystalCharlie, crystalBob;

import 'src/rust/frb_generated.dart';

class QuantusSdk {
  /// Initialise the SDK (loads Rust FFI, etc).
  static Future<void> init() async {
    print('initializing rust bindings..');
    await RustLib.init();
    print('rust bindings initialized');
  }
}
