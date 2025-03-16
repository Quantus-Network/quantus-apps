import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:polkadart/apis/apis.dart';
import 'package:polkadart/polkadart.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:polkadart_scale_codec/polkadart_scale_codec.dart' as scale_codec;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ss58/ss58.dart' hide Registry;

class WalletInfo {
  final KeyPair keyPair;
  final String address;
  final String publicKey;
  final String privateKey;
  final String accountId;

  WalletInfo({
    required this.keyPair,
    required this.address,
    required this.publicKey,
    required this.privateKey,
    required this.accountId,
  });

  factory WalletInfo.fromKeyPair(KeyPair keyPair) {
    final publicKeyHex = hex.encode(keyPair.publicKey.bytes);
    // For sr25519, we don't expose the private key directly for security
    // Instead, we store a placeholder or empty value
    final privateKeyHex = '';

    return WalletInfo(
      keyPair: keyPair,
      address: keyPair.address,
      publicKey: publicKeyHex,
      privateKey: privateKeyHex,
      accountId: keyPair.address,
    );
  }
}

class SubstrateService {
  static final SubstrateService _instance = SubstrateService._internal();
  factory SubstrateService() => _instance;
  SubstrateService._internal();

  late final Provider _provider;
  late final StateApi _stateApi;
  late final AuthorApi _authorApi;
  late final SystemApi _systemApi;
  static const String _rpcEndpoint = 'ws://127.0.0.1:9944'; // Replace with actual endpoint

  Future<void> initialize() async {
    _provider = Provider.fromUri(Uri.parse(_rpcEndpoint));
    _stateApi = StateApi(_provider);
    _authorApi = AuthorApi(_provider);
    _systemApi = SystemApi(_provider);
  }

  Future<WalletInfo> generateWalletFromSeed(String seedPhrase) async {
    try {
      final wallet = await KeyPair.sr25519.fromMnemonic(seedPhrase);
      return WalletInfo.fromKeyPair(wallet);
    } catch (e) {
      throw Exception('Failed to generate wallet: $e');
    }
  }

  Future<double> queryBalance(String address) async {
    try {
      final result = await _provider.send('system_account', [address]);
      final data = result.result as Map<String, dynamic>;
      final free = BigInt.parse(data['data']['free'].toString());
      // Convert balance to REZ (adjust decimals according to your chain's configuration)
      return free.toDouble() / BigInt.from(10).pow(12).toDouble();
    } catch (e) {
      throw Exception('Failed to query balance: $e');
    }
  }

  Future<String> balanceTransfer(String senderSeed, String targetAddress, double amount) async {
    try {
      // Get the sender's wallet
      final senderWallet = await KeyPair.sr25519.fromMnemonic(senderSeed);

      // Get necessary info for the transaction
      final runtimeVersion = await _stateApi.getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;

      final block = await _provider.send('chain_getBlock', []);
      final blockNumber = int.parse(block.result['block']['header']['number']);

      final blockHash = (await _provider.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
      final genesisHash = (await _provider.send('chain_getBlockHash', [0])).result.replaceAll('0x', '');

      // Get the next nonce for the sender
      final nonceResult = await _provider.send('system_accountNextIndex', [senderWallet.address]);
      final nonce = int.parse(nonceResult.result.toString());

      // Convert amount to chain format (considering decimals)
      final rawAmount = BigInt.from(amount * BigInt.from(10).pow(12).toInt());

      // Create the destination address
      final destPubkey = Address.decode(targetAddress).pubkey;

      // Get metadata for encoding
      final metadata = await _stateApi.getMetadata();

      // Create the call data
      final transferCall = Uint8List.fromList([
        // Module index for Balances (you'll need to get this from your chain's metadata)
        0x04,
        // Call index for transfer (you'll need to get this from your chain's metadata)
        0x00,
        // Encode the destination address
        ...destPubkey,
        // Encode the amount using simple byte representation
        ...rawAmount.toRadixString(16).padLeft(32, '0').split('').map((e) => int.parse(e, radix: 16)).toList(),
      ]);

      // Create and sign the payload
      final payloadToSign = SigningPayload(
        method: transferCall,
        specVersion: specVersion,
        transactionVersion: transactionVersion,
        genesisHash: genesisHash,
        blockHash: blockHash,
        blockNumber: blockNumber,
        eraPeriod: 64,
        nonce: nonce,
        tip: 0,
      );

      final payload = payloadToSign.encode(metadata);
      final signature = senderWallet.sign(payload);

      // Create the extrinsic
      final extrinsic = ExtrinsicPayload(
        signer: Uint8List.fromList(senderWallet.publicKey.bytes),
        method: transferCall,
        signature: signature,
        eraPeriod: 64,
        blockNumber: blockNumber,
        nonce: nonce,
        tip: 0,
      ).encode(metadata, SignatureType.sr25519);

      // Submit the extrinsic
      final hash = await _authorApi.submitExtrinsic(extrinsic);
      return hex.encode(hash);
    } catch (e) {
      throw Exception('Failed to transfer balance: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
