import 'dart:typed_data';
import 'package:polkadart/polkadart.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:resonance_network_wallet/generated/resonance/types/sp_core/crypto/account_id32.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart' as convert;

import 'generated/resonance/resonance.dart';
import 'generated/resonance/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:ss58/ss58.dart';

class WalletInfo {
  final KeyPair keyPair;
  final String accountId;
  final String? mnemonic;

  WalletInfo({
    required this.keyPair,
    required this.accountId,
    this.mnemonic,
  });

  factory WalletInfo.fromKeyPair(KeyPair keyPair, {String? mnemonic}) {
    return WalletInfo(
      keyPair: keyPair,
      accountId: keyPair.address,
      mnemonic: mnemonic,
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

  Future<WalletInfo> generateWalletFromDerivationPath(String path) async {
    try {
      // For development accounts like //Alice, we use fromUri
      final wallet = await KeyPair.sr25519.fromUri(path);

      print('Generated wallet from derivation path:');
      print('Path: $path');
      print('Address: ${wallet.address}');

      return WalletInfo.fromKeyPair(wallet);
    } catch (e) {
      throw Exception('Failed to generate wallet from derivation path: $e');
    }
  }

  Future<WalletInfo> generateWalletFromSeed(String seedPhrase) async {
    try {
      // Check if it's a development account path
      if (seedPhrase.startsWith('//')) {
        return generateWalletFromDerivationPath(seedPhrase);
      }

      // Regular mnemonic handling
      final wallet = await KeyPair.sr25519.fromMnemonic(seedPhrase);
      return WalletInfo.fromKeyPair(wallet);
    } catch (e) {
      throw Exception('Failed to generate wallet: $e');
    }
  }

  Future<double> queryBalance(String address) async {
    try {
      // Create Resonance API instance
      final resonanceApi = Resonance(_provider);

      print('queryBalance Address: $address');

      // Account from SS58 address
      final account = Address.decode(address);

      print('Account pubkey: ${account.pubkey}');

      // Retrieve Account Balance
      final accountInfo = await resonanceApi.query.system.account(account.pubkey);
      print('Balance: ${accountInfo.data.free}');

      // Get the free balance
      final free = accountInfo.data.free;

      // Convert balance to REZ (12 decimals)
      return free.toDouble() / BigInt.from(10).pow(12).toDouble();
    } catch (e) {
      print('Error querying balance: $e');
      throw Exception('Failed to query balance: $e');
    }
  }

  Future<String> balanceTransfer(String senderSeed, String targetAddress, double amount) async {
    try {
      // Get the sender's wallet
      final senderWallet = await KeyPair.sr25519.fromMnemonic(senderSeed);
      // create our keypair here instead.
      // to change this to ml-dsa signing, really all we need to do is change the keypair type and the signature. 
      // the rest is the same
      // ml-dsa signatures consist of public key + signature. 
    

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

      final dest = targetAddress;
      final multiDest = const multi_address.$MultiAddress().id(Address.decode(dest).pubkey);
      print('Destination: $dest');

      // Encode call
      final resonanceApi = Resonance(_provider);
      final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(dest: multiDest, value: BigInt.from(1000));
      final transferCall = runtimeCall.encode();

      // // Create the destination address bytes
      // final destBytes = hex.decode(targetAddress.replaceAll('0x', ''));

      // Get metadata for encoding
      final metadata = await _stateApi.getMetadata();

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
      return convert.hex.encode(hash);
    } catch (e) {
      throw Exception('Failed to transfer balance: $e');
    }
  }

  // reference implementation - this works with sr25519 schnorr signatures
  Future<String> balanceTransferSr25519(String senderSeed, String targetAddress, double amount) async {
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

      final dest = targetAddress;
      final multiDest = const multi_address.$MultiAddress().id(Address.decode(dest).pubkey);
      print('Destination: $dest');

      // Encode call
      final resonanceApi = Resonance(_provider);
      final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(dest: multiDest, value: BigInt.from(1000));
      final transferCall = runtimeCall.encode();

      // // Create the destination address bytes
      // final destBytes = hex.decode(targetAddress.replaceAll('0x', ''));

      // Get metadata for encoding
      final metadata = await _stateApi.getMetadata();

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
      return convert.hex.encode(hash);
    } catch (e) {
      throw Exception('Failed to transfer balance: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String> generateMnemonic() async {
    try {
      // Generate a random entropy
      final entropy = List<int>.generate(32, (i) => Random.secure().nextInt(256));
      // Convert entropy to a hexadecimal string
      final entropyHex = convert.hex.encode(entropy);
      // Generate mnemonic from entropy
      final mnemonic = bip39.entropyToMnemonic(entropyHex);
      return mnemonic;
    } catch (e) {
      throw Exception('Failed to generate mnemonic: $e');
    }
  }

  Future<WalletInfo> generateNewWallet(String mnemonic) async {
    try {
      // Create a wallet from the mnemonic
      final wallet = await KeyPair.sr25519.fromMnemonic(mnemonic);

      print('Generated new wallet:');
      print('Address: ${wallet.address}');

      return WalletInfo.fromKeyPair(wallet, mnemonic: mnemonic);
    } catch (e) {
      throw Exception('Failed to generate new wallet: $e');
    }
  }
}
