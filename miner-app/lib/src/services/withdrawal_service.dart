import 'package:quantus_miner/src/services/miner_settings_service.dart';
import 'package:quantus_miner/src/services/transfer_tracking_service.dart';
import 'package:quantus_miner/src/services/wormhole_address_manager.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;

typedef WithdrawalProgressCallback = sdk.WithdrawalProgressCallback;
typedef WithdrawalResult = sdk.WithdrawalResult;

class WithdrawalService {
  final MinerSettingsService _settingsService;
  final sdk.WormholeWithdrawalService _sdkWithdrawalService;

  WithdrawalService({
    MinerSettingsService? settingsService,
    sdk.WormholeWithdrawalService? sdkWithdrawalService,
  }) : _settingsService = settingsService ?? MinerSettingsService(),
       _sdkWithdrawalService =
           sdkWithdrawalService ?? sdk.WormholeWithdrawalService();

  Future<WithdrawalResult> withdraw({
    required String secretHex,
    required String wormholeAddress,
    required String destinationAddress,
    BigInt? amount,
    required String circuitBinsDir,
    List<TrackedTransfer>? trackedTransfers,
    WormholeAddressManager? addressManager,
    WithdrawalProgressCallback? onProgress,
  }) async {
    final transfers = trackedTransfers
        ?.map<sdk.WormholeTransferInfo>(
          (t) => sdk.WormholeTransferInfo(
            blockHash: t.blockHash,
            transferCount: t.transferCount,
            leafIndex: t.leafIndex,
            amount: t.amount,
            wormholeAddress: t.wormholeAddress,
            fundingAccount: t.fundingAccount,
            fundingAccountHex: t.fundingAccountHex,
          ),
        )
        .toList();

    if (transfers == null || transfers.isEmpty) {
      return const WithdrawalResult(
        success: false,
        error:
            'No tracked transfers available. Mining rewards can only be withdrawn '
            'for blocks mined while the app was open. Please mine some blocks first.',
      );
    }

    final chainConfig = await _settingsService.getChainConfig();

    return _sdkWithdrawalService.withdraw(
      rpcUrl: chainConfig.rpcUrl,
      secretHex: secretHex,
      wormholeAddress: wormholeAddress,
      destinationAddress: destinationAddress,
      amount: amount,
      circuitBinsDir: circuitBinsDir,
      transfers: transfers,
      addressManager: addressManager,
      onProgress: onProgress,
    );
  }
}
