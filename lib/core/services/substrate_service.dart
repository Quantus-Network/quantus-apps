import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

import 'package:resonance_network_wallet/generated/resonance/resonance.dart';
import 'package:resonance_network_wallet/generated/resonance/types/sp_runtime/multiaddress/multi_address.dart'
    as multi_address;
import 'package:ss58/ss58.dart';
import 'package:resonance_network_wallet/src/rust/api/crypto.dart' as crypto;
import 'package:resonance_network_wallet/resonance_extrinsic_payload.dart';

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

class DilithiumWalletInfo {
  final crypto.Keypair keypair;
  final String accountId;
  final String? mnemonic;

  DilithiumWalletInfo({
    required this.keypair,
    required this.accountId,
    this.mnemonic,
  });

  factory DilithiumWalletInfo.fromKeyPair(crypto.Keypair keypair, {String? mnemonic}) {
    return DilithiumWalletInfo(
      keypair: keypair,
      accountId: keypair.ss58Address,
      mnemonic: mnemonic,
    );
  }
}

const crystalAlice = '//Crystal Alice';
const crystalBob = '//Crystal Bob';
const crystalCharlie = '//Crystal Charlie';

extension on Address {
  // making an alias here because pubkey is not a public key it's just the raw decoded address - decoding from ss58 to a bytes array
  Uint8List get addressByes => pubkey;
}

// Dilithium Keypair
// This differs from the built in keypairs in that the public key is very long.
// The address is a poseidon hash of the public key.
// We get the address as ss58 from our library, and we can convert it back into bytes if needed.
extension on crypto.Keypair {
  String get ss58Address => crypto.toAccountId(obj: this);
  Uint8List get addressBytes => Address.decode(ss58Address).addressByes;
}

class SubstrateService {
  static final SubstrateService _instance = SubstrateService._internal();
  factory SubstrateService() => _instance;
  SubstrateService._internal();

  late final Provider _provider;
  late final StateApi _stateApi;
  late final AuthorApi _authorApi;
  // ignore: unused_field
  late final SystemApi _systemApi;
  static const String _rpcEndpoint = 'ws://127.0.0.1:9944'; // Replace with actual endpoint

  Future<void> initialize() async {
    _provider = Provider.fromUri(Uri.parse(_rpcEndpoint));
    _stateApi = StateApi(_provider);
    _authorApi = AuthorApi(_provider);
    _systemApi = SystemApi(_provider);
  }

  String formatBalance(BigInt balance) {
    return balance.toString();

    // final _numberFormat = NumberFormat("#,##0.000000000000", "en_US");
    // Convert to decimal string considering 12 decimal places
    // final decimal = balance.toString().padLeft(13, '0');
    // final integerPart = decimal.substring(0, decimal.length - 12);
    // final fractionalPart = decimal.substring(decimal.length - 12);

    // // Format with commas for thousands
    // final formattedInteger = _numberFormat.format(int.parse(integerPart));

    // // Combine with fractional part
    // return '$formattedInteger.$fractionalPart';
  }

  Future<WalletInfo> generateWalletFromDerivationPath(String path) async {
    try {
      // For development accounts like //Alice, we use fromUri
      final wallet = await KeyPair.sr25519.fromUri(path);

      debugPrint('Generated wallet from derivation path:');
      debugPrint('Path: $path');
      debugPrint('Address: ${wallet.address}');

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

  Future<DilithiumWalletInfo> generateWalletFromSeedDilithium(String seedPhrase) async {
    try {
      crypto.Keypair keypair = dilithiumKeypairFromMnemonic(seedPhrase);
      return DilithiumWalletInfo.fromKeyPair(keypair);
    } catch (e) {
      throw Exception('Failed to generate wallet: $e');
    }
  }

  Future<WalletInfo> generateWalletFromSeedssr25519(String seedPhrase) async {
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

  Future<BigInt> queryBalance(String address) async {
    try {
      // Create Resonance API instance
      final resonanceApi = Resonance(_provider);
      // Account from SS58 address
      final account = Address.decode(address);

      // debugPrint('Account pubkey: ${account.pubkey}');

      // Retrieve Account Balance
      final accountInfo = await resonanceApi.query.system.account(account.pubkey);
      // debugPrint('Balance for $address: ${accountInfo.data.free}');

      // Get the free balance
      return accountInfo.data.free;
    } catch (e) {
      debugPrint('Error querying balance: $e');
      throw Exception('Failed to query balance: $e');
    }
  }

  Uint8List _combineSignatureAndPubkey(List<int> signature, List<int> pubkey) {
    final result = Uint8List(signature.length + pubkey.length);
    result.setAll(0, signature);
    result.setAll(signature.length, pubkey);
    return result;
  }

  Future<void> _printBalance(String prefix, String address) async {
    final balance = await queryBalance(address);
    debugPrint('$prefix Balance for $address: ${balance.toString()}');
  }

  crypto.Keypair dilithiumKeypairFromMnemonic(String senderSeed) {
    crypto.Keypair senderWallet;
    if (senderSeed.startsWith('//')) {
      switch (senderSeed) {
        case crystalAlice:
          senderWallet = crypto.crystalAlice();
          break;
        case crystalBob:
          senderWallet = crypto.crystalBob();
          break;
        case crystalCharlie:
          senderWallet = crypto.crystalCharlie();
          break;
        default:
          throw Exception('Invalid sender seed: $senderSeed');
      }
    } else {
      // Get the sender's wallet
      senderWallet = crypto.generateKeypair(mnemonicStr: senderSeed);
    }
    return senderWallet;
  }

  // reference implementation - this works with sr25519 schnorr signatures
  Future<String> balanceTransfer2(String senderSeed, String targetAddress, double amount) async {
    try {
      // Get the sender's wallet
      debugPrint('creating key with $senderSeed');
      debugPrint('sending to $targetAddress');
      debugPrint('amount $amount');

      crypto.Keypair senderWallet = dilithiumKeypairFromMnemonic(senderSeed);

      await _printBalance('before ', senderWallet.ss58Address);
      await _printBalance('before ', targetAddress);

      // Get necessary info for the transaction
      final runtimeVersion = await _stateApi.getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;

      final block = await _provider.send('chain_getBlock', []);
      final blockNumber = int.parse(block.result['block']['header']['number']);

      final blockHash = (await _provider.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
      final genesisHash = (await _provider.send('chain_getBlockHash', [0])).result.replaceAll('0x', '');

      // Get the next nonce for the `sender`
      final nonceResult = await _provider.send('system_accountNextIndex', [senderWallet.ss58Address]);
      final nonce = int.parse(nonceResult.result.toString());

      // Convert amount to chain format (considering decimals)
      // TODO actually figure out the amount...
      final rawAmount = BigInt.from(amount);

      final dest = targetAddress;
      final multiDest = const multi_address.$MultiAddress().id(Address.decode(dest).pubkey);
      debugPrint('Destination: $dest');

      // Encode call
      final resonanceApi = Resonance(_provider);
      final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(dest: multiDest, value: rawAmount);
      final transferCall = runtimeCall.encode();

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

      final payload = payloadToSign.encode(resonanceApi.registry);

      final signature = crypto.signMessage(keypair: senderWallet, message: payload);

      final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(signature, senderWallet.publicKey);

      // final signature = senderWallet.sign(payload);

      // Create the extrinsic
      final extrinsic = ResonanceExtrinsicPayload(
        signer: Uint8List.fromList(senderWallet.addressBytes),
        method: transferCall,
        signature: signatureWithPublicKeyBytes,
        eraPeriod: 64,
        blockNumber: blockNumber,
        nonce: nonce,
        tip: 0,
      ).encodeResonance(resonanceApi.registry, ResonanceSignatureType.resonance);

      // Submit the extrinsic

      await _authorApi.submitAndWatchExtrinsic(extrinsic, (data) async {
        debugPrint('type: ${data.type}, value: ${data.value}');

        await _printBalance('after ', senderWallet.ss58Address);
        await _printBalance('after ', targetAddress);
      });
      return '0';

      // final hash = await _authorApi.submitExtrinsic(extrinsic);
      // return convert.hex.encode(0);
    } catch (e, stackTrace) {
      debugPrint('Failed to transfer balance: $e');
      debugPrint('Failed to transfer balance: $stackTrace');

      throw Exception('Failed to transfer balance: $e');
    }
  }

  // reference implementation - this works with sr25519 schnorr signatures
  Future<String> balanceTransferSr25519(String senderSeed, String targetAddress, double amount) async {
    try {
      // Get the sender's wallet
      final senderWallet = await KeyPair.sr25519.fromMnemonic(senderSeed);

      debugPrint('sender\' wallet: ${senderWallet.address}');

      // Get necessary info for the transaction
      final runtimeVersion = await _stateApi.getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;

      final block = await _provider.send('chain_getBlock', []);
      final blockNumber = int.parse(block.result['block']['header']['number']);

      final blockHash = (await _provider.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
      final genesisHash = (await _provider.send('chain_getBlockHash', [0])).result.replaceAll('0x', '');

      // Get the next nonce for the `sender`
      final nonceResult = await _provider.send('system_accountNextIndex', [senderWallet.address]);
      final nonce = int.parse(nonceResult.result.toString());

      // Convert amount to chain format (considering decimals)
      final rawAmount = BigInt.from(amount * BigInt.from(10).pow(12).toInt());

      final dest = targetAddress;
      final multiDest = const multi_address.$MultiAddress().id(Address.decode(dest).pubkey);
      debugPrint('Destination: $dest');

      // Encode call
      final resonanceApi = Resonance(_provider);
      final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(dest: multiDest, value: rawAmount);
      final transferCall = runtimeCall.encode();

      // Get metadata for encoding
      // final metadata = await _stateApi.getMetadata();

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

      final payload = payloadToSign.encode(resonanceApi.registry);

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
      ).encode(resonanceApi.registry, SignatureType.sr25519);

      // Submit the extrinsic

      await _authorApi.submitAndWatchExtrinsic(extrinsic, (data) {
        debugPrint('type: ${data.type}, value: ${data.value}');
      });
      return '0';

      // final hash = await _authorApi.submitExtrinsic(extrinsic);
      // return convert.hex.encode(0);
    } catch (e, stackTrace) {
      debugPrint('Failed to transfer balance: $e');
      debugPrint('Failed to transfer balance: $stackTrace');
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
      // Generate mnemonic from entropy
      final mnemonic = Mnemonic(entropy, Language.english);

      return mnemonic.sentence;
    } catch (e) {
      throw Exception('Failed to generate mnemonic: $e');
    }
  }

  Future<WalletInfo> generateNewWallet(String mnemonic) async {
    try {
      // Create a wallet from the mnemonic
      final wallet = await KeyPair.sr25519.fromMnemonic(mnemonic);

      debugPrint('Generated new wallet:');
      debugPrint('Address: ${wallet.address}');

      return WalletInfo.fromKeyPair(wallet, mnemonic: mnemonic);
    } catch (e) {
      throw Exception('Failed to generate new wallet: $e');
    }
  }
}
