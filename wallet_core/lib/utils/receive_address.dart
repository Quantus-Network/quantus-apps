import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// Where [account] is paid. An encrypted account hands out its wallet's next
/// unused deposit (wormhole) address, which is shared linearly with change
/// addresses, so its deposits cannot be linked to each other; any other
/// account is paid at its own address.
Future<String> receiveAddress(ProviderReader read, BaseAccount account) async {
  if (!isEncryptedAccount(account)) return account.accountId;
  final service = read(encryptedAccountServiceProvider((account as Account).walletIndex));
  return (await service.receiveKeyPair()).address;
}
