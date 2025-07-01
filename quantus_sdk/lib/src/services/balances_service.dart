import 'package:quantus_sdk/generated/resonance/resonance.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/generated/resonance/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'substrate_service.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class BalancesService {
  static final BalancesService _instance = BalancesService._internal();
  factory BalancesService() => _instance;
  BalancesService._internal();

  final SubstrateService _substrateService = SubstrateService();

  Future<String> balanceTransfer(String senderSeed, String targetAddress, BigInt amount) async {
    try {
      final resonanceApi = Resonance(_substrateService.provider!);
      final multiDest = const multi_address.$MultiAddress().id(crypto.ss58ToAccountId(s: targetAddress));

      final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(dest: multiDest, value: amount);

      // Submit the extrinsic and return its result
      return await _substrateService.submitExtrinsic(
        senderSeed,
        runtimeCall,
        onStatus: (data) async {
          print('type: ${data.type}, value: ${data.value}');
        },
      );
    } catch (e, stackTrace) {
      print('Failed to transfer balance: $e');
      print('Failed to transfer balance: $stackTrace');
      throw Exception('Failed to transfer balance: $e');
    }
  }
}
