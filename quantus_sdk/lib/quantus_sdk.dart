library;

import 'package:quantus_sdk/src/rust/api/crypto.dart';
import 'package:quantus_sdk/src/services/settings_service.dart';

import 'src/rust/frb_generated.dart';

export 'generated/planck/pallets/balances.dart';
export 'generated/planck/types/quantus_runtime/runtime_call.dart';
export 'src/constants/app_constants.dart';
export 'src/extensions/color_extensions.dart';
export 'src/extensions/context_extension.dart';
export 'src/extensions/decimal_input_filter.dart';
export 'src/extensions/keypair_extensions.dart';
export 'src/extensions/string_extensions.dart';
// UI-related exports
export 'src/models/account.dart';
export 'src/models/base_account.dart';
export 'src/models/high_security_data.dart';
export 'src/models/account_stats.dart';
export 'src/models/account_associations.dart';
export 'src/models/event_type.dart';
export 'src/models/extrinsic_data.dart';
export 'src/models/extrinsic_fee_data.dart';
export 'src/models/unsigned_transaction_data.dart';
export 'src/models/remote_config_model.dart';
export 'src/models/miner_reward_event.dart';
export 'src/models/miner_stats.dart';
export 'src/models/opted_in_position.dart';
export 'src/models/pending_transfer_event.dart';
export 'src/models/reversible_transfer_status.dart';
export 'src/models/sorted_transactions.dart';
export 'src/models/transaction_event.dart';
export 'src/models/transaction_filter.dart';
export 'src/models/transaction_state.dart';
export 'src/models/raider_submissions.dart';
export 'src/models/raid_quest.dart';
export 'src/models/referral_rank.dart';
export 'src/models/raid_stats.dart';
// note we have to hide some things here because they're exported by substrate service
// should probably expise all of crypto.dart through substrateservice instead
export 'src/rust/api/crypto.dart' hide crystalAlice, crystalCharlie, crystalBob;
export 'src/rust/api/ur.dart';
export 'src/rust/api/wormhole.dart';
export 'src/services/account_discovery_service.dart';
export 'src/services/accounts_service.dart';
export 'src/services/address_formatting_service.dart';
export 'src/services/balances_service.dart';
export 'src/services/chain_history_service.dart';
export 'src/services/connectivity_service.dart';
export 'src/services/datetime_formatting_service.dart';
export 'src/services/hd_wallet_service.dart';
export 'src/services/high_security_service.dart';
export 'src/services/human_readable_checksum_service.dart';
export 'src/services/migration_service.dart';
export 'src/services/network/redundant_endpoint.dart';
export 'src/services/locale_number_config.dart';
export 'src/services/number_formatting_service.dart';
export 'src/services/recent_addresses_service.dart';
export 'src/services/recovery_service.dart';
export 'src/services/reversible_transfers_service.dart';
export 'src/services/settings_service.dart';
export 'src/services/substrate_service.dart';
export 'src/services/swap_service.dart';
export 'src/services/taskmaster_service.dart';
export 'src/services/senoti_service.dart';
export 'src/services/circuit_manager.dart';
export 'src/services/wormhole_address_manager.dart';
export 'src/services/wormhole_utxo_service.dart';
export 'src/extensions/account_extension.dart';
export 'src/quantus_signing_payload.dart';
export 'src/quantus_payload_parser.dart';
export 'src/models/entrusted_account.dart';
export 'src/models/display_account.dart';

// Blockchain-infrastructure third-party re-exports. Apps consume these via
// the SDK rather than depending on polkadart / bip39_mnemonic directly.
export 'package:bip39_mnemonic/bip39_mnemonic.dart' show Mnemonic, Language;
export 'package:polkadart/scale_codec.dart' show ByteOutput, CompactCodec;

class QuantusSdk {
  /// Initialise the SDK (loads Rust FFI, etc).
  static Future<void> init() async {
    await RustLib.init();
    await SettingsService().initialize();
    setDefaultSs58Prefix(prefix: 189);
  }
}
