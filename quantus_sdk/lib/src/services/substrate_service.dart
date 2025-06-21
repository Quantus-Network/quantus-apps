import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart';
import 'package:ss58/ss58.dart';
import '../constants/app_constants.dart';
import '../extensions/keypair_extensions.dart';
import 'number_formatting_service.dart';
import 'dart:math';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';

import 'package:quantus_sdk/generated/resonance/resonance.dart';
import 'package:quantus_sdk/generated/resonance/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/resonance_extrinsic_payload.dart';
import 'settings_service.dart';

enum ConnectionStatus { connecting, connected, disconnected, error }

class DilithiumWalletInfo {
  final crypto.Keypair keypair;
  final String accountId;
  final String? mnemonic;
  final String walletName;
  DilithiumWalletInfo({required this.keypair, required this.accountId, this.mnemonic, required this.walletName});

  factory DilithiumWalletInfo.fromKeyPair(crypto.Keypair keypair, {required String walletName, String? mnemonic}) {
    return DilithiumWalletInfo(
      keypair: keypair,
      accountId: keypair.ss58Address,
      mnemonic: mnemonic,
      walletName: walletName,
    );
  }
}

const crystalAlice = '//Crystal Alice';
const crystalBob = '//Crystal Bob';
const crystalCharlie = '//Crystal Charlie';

extension on Address {
  // Address is used to convert between ss58 Strings and AccountID32 bytes.
  // The ss58 package assumes Ed25519 addresses, and it assumes that AccountID32 for an ss58 address is
  // the same as the public key.
  // That is not true for dilithium signatures, where AccoundID32 is a
  // Poseidon hash of the public key.
  // Just to explain why this field is named pubkey - it's not a pub key in our signature scheme.
  // However, we can still use this class to convert between ss58 Strings and AccountID32 bytes.
  Uint8List get addressBytes => pubkey;
}

// equivalent to crypto.ss58ToAccountId(s: ss58Address)
Uint8List getAccountId32(String ss58Address) {
  return Address.decode(ss58Address).addressBytes;
}

class SubstrateService {
  final SettingsService _settingsService;

  Provider? _provider;
  StateApi? _stateApi;
  AuthorApi? _authorApi;
  static const String _rpcEndpoint = AppConstants.rpcEndpoint;

  // Add StreamController for connection status
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();

  // Expose the stream
  Stream<ConnectionStatus> get connectionStatus => _connectionStatusController.stream;

  SubstrateService(this._settingsService);

  Future<void> initialize() async {
    // Only create the provider if it hasn't been created yet
    // If it exists, assume it's already connected or will attempt to reconnect automatically.
    if (_provider == null) {
      _provider = Provider.fromUri(Uri.parse(_rpcEndpoint));
      // Initialize APIs with the new provider
      _stateApi = StateApi(_provider!);
      _authorApi = AuthorApi(_provider!);
    }

    // Attempt to connect
    try {
      _connectionStatusController.add(ConnectionStatus.connecting);
      // Only attempt to connect if provider was just created or is not currently connecting/connected
      // A simple check for null provider implies it needs connecting
      if (_provider != null) {
        await _provider!.connect().timeout(const Duration(seconds: 15));
        _connectionStatusController.add(ConnectionStatus.connected);
      }
    } catch (e) {
      _connectionStatusController.add(ConnectionStatus.error);
      print('Initial connection failed: $e');
      // Optionally rethrow or handle based on app's startup requirements
    }
  }

  Future<void> reconnect() async {
    print('Attempting to recreate and reconnect Substrate provider...');
    const Duration networkTimeout = Duration(seconds: 15);

    // Dispose of the old provider instance if it exists
    // Note: Polkadart Provider might not have a public dispose/close.
    // Relying on garbage collection or checking Polkadart docs for proper cleanup.
    // To force re-initialization with a potentially new connection,
    // we'll create a new Provider instance.
    _provider = Provider.fromUri(Uri.parse(_rpcEndpoint));

    // Re-initialize APIs with the new provider
    _stateApi = StateApi(_provider!);
    _authorApi = AuthorApi(_provider!);

    // Attempt to connect the new provider with timeout
    try {
      _connectionStatusController.add(ConnectionStatus.connecting);
      await _provider!.connect().timeout(networkTimeout);
      _connectionStatusController.add(ConnectionStatus.connected);
      print('New provider connected successfully during reconnect.');
    } catch (e) {
      _connectionStatusController.add(ConnectionStatus.disconnected); // Or error
      print('Failed to recreate/reconnect provider: $e');
      if (e is TimeoutException) {
        throw Exception('Failed to reconnect to the network: Connection timed out.');
      } else {
        throw Exception('Failed to reconnect to the network: $e');
      }
    }
  }

  Future<BigInt> getFee(String senderAddress, String recipientAddress, BigInt amount) async {
    try {
      final resonanceApi = Resonance(_provider!);
      final multiDest = const multi_address.$MultiAddress().id(getAccountId32(recipientAddress));

      // Retrieve sender's mnemonic and generate keypair
      // Assuming senderAddress corresponds to the current wallet's account ID
      crypto.Keypair senderWallet = await _getUserWallet();

      // Get necessary info for the transaction (similar to balanceTransfer)
      final runtimeVersion = await _stateApi!.getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;

      final block = await _provider!.send('chain_getBlock', []);
      final blockNumber = int.parse(block.result['block']['header']['number']);

      final blockHash = (await _provider!.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
      final genesisHash = (await _provider!.send('chain_getBlockHash', [0])).result.replaceAll('0x', '');

      // Get the next nonce for the sender
      final nonceResult = await _provider!.send('system_accountNextIndex', [senderWallet.ss58Address]);
      final nonce = int.parse(nonceResult.result.toString());

      // Create the call for fee estimation
      final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(dest: multiDest, value: amount);
      final transferCall = runtimeCall.encode();

      // Create and sign a dummy payload for fee estimation
      final payloadToSign = SigningPayload(
        method: transferCall,
        specVersion: specVersion,
        transactionVersion: transactionVersion,
        genesisHash: genesisHash,
        blockHash: blockHash,
        blockNumber: blockNumber,
        eraPeriod: 64, // Use a reasonable era period
        nonce: nonce,
        tip: 0, // Assuming no tip for fee estimation
      );

      final payload = payloadToSign.encode(resonanceApi.registry);
      final signature = crypto.signMessage(keypair: senderWallet, message: payload);

      // Construct the signed extrinsic payload (Resonance specific)
      final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(signature, senderWallet.publicKey); // Reuse helper

      final signedExtrinsic = ResonanceExtrinsicPayload(
        signer: Uint8List.fromList(senderWallet.addressBytes), // Use signer address bytes
        method: transferCall, // The encoded call method
        signature: signatureWithPublicKeyBytes, // The signature
        eraPeriod: 64, // Must match SigningPayload
        blockNumber: blockNumber, // Must match SigningPayload
        nonce: nonce, // Must match SigningPayload
        tip: 0, // Must match SigningPayload
      ).encodeResonance(resonanceApi.registry, ResonanceSignatureType.resonance);

      // Convert encoded signed extrinsic to hex string
      final hexEncodedSignedExtrinsic = bytesToHex(signedExtrinsic);

      // Use provider.send to call the payment_queryInfo RPC with the signed extrinsic
      final result = await _provider!.send('payment_queryInfo', [
        hexEncodedSignedExtrinsic,
        null,
      ]); // null for block hash

      // Parse the result to get the partialFee
      // The result structure is typically {'partialFee': '...'} for this RPC
      final partialFeeString = result.result['partialFee'] as String;
      final partialFee = BigInt.parse(partialFeeString);

      print('partialFee: $partialFee');

      return partialFee;
    } catch (e) {
      // If a network error occurs here, update the connection status
      if (e.toString().contains('WebSocketChannelException') || e is SocketException || e is TimeoutException) {
        _connectionStatusController.add(ConnectionStatus.disconnected);
      }
      print('Error estimating fee: $e');
      throw Exception('Failed to estimate network fee: $e');
    }
  }

  Future<crypto.Keypair> _getUserWallet() async {
    final settingsService = _settingsService;
    final senderSeed = await settingsService.getMnemonic();
    if (senderSeed == null || senderSeed.isEmpty) {
      throw Exception('Sender mnemonic not found for fee estimation.');
    }
    crypto.Keypair senderWallet = dilithiumKeypairFromMnemonic(senderSeed);
    return senderWallet;
  }

  Future<DilithiumWalletInfo> generateWalletFromSeed(String seedPhrase) async {
    try {
      crypto.Keypair keypair = dilithiumKeypairFromMnemonic(seedPhrase);
      return DilithiumWalletInfo.fromKeyPair(keypair, walletName: '');
    } catch (e) {
      throw Exception('Failed to generate wallet: $e');
    }
  }

  // Fetch balance of current user
  Future<BigInt> queryUserBalance() async {
    final keyPair = await _getUserWallet();
    final balance = await queryBalance(keyPair.ss58Address);
    return balance;
  }

  Future<BigInt> queryBalance(String address) async {
    try {
      // Create Resonance API instance
      final resonanceApi = Resonance(_provider!);
      // Account from SS58 address
      final accountID = crypto.ss58ToAccountId(s: address);

      // Retrieve Account Balance
      final accountInfo = await resonanceApi.query.system.account(accountID);

      // Get the free balance
      return accountInfo.data.free;
    } catch (e) {
      // If a network error occurs here, update the connection status
      if (e.toString().contains('WebSocketChannelException') || e is SocketException || e is TimeoutException) {
        _connectionStatusController.add(ConnectionStatus.disconnected);
      }
      print('Error querying balance: $e');
      throw Exception('Failed to query balance: $e');
    }
  }

  Uint8List _combineSignatureAndPubkey(List<int> signature, List<int> pubkey) {
    final result = Uint8List(signature.length + pubkey.length);
    result.setAll(0, signature);
    result.setAll(signature.length, pubkey);

    // Calculate and print signature checksum
    final signatureHash = sha256.convert(signature).bytes;
    final signatureChecksum = base64.encode(signatureHash).substring(0, 8);
    print('Signature checksum: $signatureChecksum');

    return result;
  }

  Future<void> _printBalance(String prefix, String address) async {
    final balance = await queryBalance(address);
    print('$prefix Balance for $address: ${balance.toString()}');
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

  Future<String> balanceTransfer(String senderSeed, String targetAddress, BigInt amount) async {
    try {
      // Ensure provider is connected before proceeding
      if (_provider == null) {
        await initialize();
      }

      // Get the sender's wallet
      print('sending to $targetAddress');
      print('amount (BigInt): $amount');
      print('amount (${AppConstants.tokenSymbol} formatted): ${NumberFormattingService().formatBalance(amount)}');

      crypto.Keypair senderWallet = dilithiumKeypairFromMnemonic(senderSeed);

      await _printBalance('Sender before ', senderWallet.ss58Address);
      await _printBalance('Target before ', targetAddress);

      // Get all necessary info for the transaction in one go to minimize timing issues
      final runtimeVersion = await _stateApi!.getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;

      final block = await _provider!.send('chain_getBlock', []);
      final blockNumber = int.parse(block.result['block']['header']['number']);
      final blockHash = (await _provider!.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
      final genesisHash = (await _provider!.send('chain_getBlockHash', [0])).result.replaceAll('0x', '');
      final nonceResult = await _provider!.send('system_accountNextIndex', [senderWallet.ss58Address]);
      final nonce = int.parse(nonceResult.result.toString());

      // Use the passed BigInt amount directly
      final BigInt rawAmount = amount;

      final dest = targetAddress;
      final destinationAccountID = crypto.ss58ToAccountId(s: dest);
      final multiDest = const multi_address.$MultiAddress().id(destinationAccountID);
      print('Destination: $dest');

      // Encode call
      final resonanceApi = Resonance(_provider!);
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

      // Create the extrinsic
      var extrinsic = ResonanceExtrinsicPayload(
        signer: Uint8List.fromList(senderWallet.addressBytes),
        method: transferCall,
        signature: signatureWithPublicKeyBytes,
        eraPeriod: 64,
        blockNumber: blockNumber,
        nonce: nonce,
        tip: 0,
      ).encodeResonance(resonanceApi.registry, ResonanceSignatureType.resonance);

      // Add retry logic for submission
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          await _authorApi!.submitAndWatchExtrinsic(extrinsic, (data) async {
            print('type: ${data.type}, value: ${data.value}');
            await _printBalance('after ', senderWallet.ss58Address);
            await _printBalance('after ', targetAddress);
          });
          return '0';
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) rethrow;
          // Wait a bit before retrying
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
          // Refresh block info for retry
          final newBlock = await _provider!.send('chain_getBlock', []);
          final newBlockNumber = int.parse(newBlock.result['block']['header']['number']);
          final newBlockHash = (await _provider!.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
          final newNonceResult = await _provider!.send('system_accountNextIndex', [senderWallet.ss58Address]);
          final newNonce = int.parse(newNonceResult.result.toString());

          // Recreate payload with new block info
          final newPayloadToSign = SigningPayload(
            method: transferCall,
            specVersion: specVersion,
            transactionVersion: transactionVersion,
            genesisHash: genesisHash,
            blockHash: newBlockHash,
            blockNumber: newBlockNumber,
            eraPeriod: 64,
            nonce: newNonce,
            tip: 0,
          );

          final newPayload = newPayloadToSign.encode(resonanceApi.registry);
          final newSignature = crypto.signMessage(keypair: senderWallet, message: newPayload);
          final newSignatureWithPublicKeyBytes = _combineSignatureAndPubkey(newSignature, senderWallet.publicKey);

          extrinsic = ResonanceExtrinsicPayload(
            signer: Uint8List.fromList(senderWallet.addressBytes),
            method: transferCall,
            signature: newSignatureWithPublicKeyBytes,
            eraPeriod: 64,
            blockNumber: newBlockNumber,
            nonce: newNonce,
            tip: 0,
          ).encodeResonance(resonanceApi.registry, ResonanceSignatureType.resonance);
        }
      }

      return '0';
    } catch (e, stackTrace) {
      print('Failed to transfer balance: $e');
      print('Failed to transfer balance: $stackTrace');
      throw Exception('Failed to transfer balance: $e');
    }
  }

  // // reference implementation - this works with sr25519 schnorr signatures
  // Future<String> balanceTransferSr25519Deprecated(String senderSeed, String targetAddress, double amount) async {
  //   try {
  //     // Get the sender's wallet
  //     final senderWallet = await KeyPair.sr25519.fromMnemonic(senderSeed);

  //     print('sender\' wallet: ${senderWallet.address}');

  //     // Get necessary info for the transaction
  //     final runtimeVersion = await _stateApi!.getRuntimeVersion();
  //     final specVersion = runtimeVersion.specVersion;
  //     final transactionVersion = runtimeVersion.transactionVersion;

  //     final block = await _provider!.send('chain_getBlock', []);
  //     final blockNumber = int.parse(block.result['block']['header']['number']);

  //     final blockHash = (await _provider!.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
  //     final genesisHash = (await _provider!.send('chain_getBlockHash', [0])).result.replaceAll('0x', '');

  //     // Get the next nonce for the `sender`
  //     final nonceResult = await _provider!.send('system_accountNextIndex', [senderWallet.address]);
  //     final nonce = int.parse(nonceResult.result.toString());

  //     // Convert amount to chain format (considering decimals)
  //     final rawAmount = BigInt.from(amount * BigInt.from(10).pow(12).toInt());

  //     final dest = targetAddress;
  //     final multiDest = const multi_address.$MultiAddress().id(Address.decode(dest).pubkey);
  //     print('Destination: $dest');

  //     // Encode call
  //     final resonanceApi = Resonance(_provider!);
  //     final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(dest: multiDest, value: rawAmount);
  //     final transferCall = runtimeCall.encode();

  //     // Get metadata for encoding
  //     // final metadata = await _stateApi.getMetadata();

  //     // Create and sign the payload
  //     final payloadToSign = SigningPayload(
  //       method: transferCall,
  //       specVersion: specVersion,
  //       transactionVersion: transactionVersion,
  //       genesisHash: genesisHash,
  //       blockHash: blockHash,
  //       blockNumber: blockNumber,
  //       eraPeriod: 64,
  //       nonce: nonce,
  //       tip: 0,
  //     );

  //     final payload = payloadToSign.encode(resonanceApi.registry);

  //     final signature = senderWallet.sign(payload);

  //     // Create the extrinsic
  //     final extrinsic = ExtrinsicPayload(
  //       signer: Uint8List.fromList(senderWallet.publicKey.bytes),
  //       method: transferCall,
  //       signature: signature,
  //       eraPeriod: 64,
  //       blockNumber: blockNumber,
  //       nonce: nonce,
  //       tip: 0,
  //     ).encode(resonanceApi.registry, SignatureType.sr25519);

  //     // Submit the extrinsic

  //     await _authorApi!.submitAndWatchExtrinsic(extrinsic, (data) {
  //       print('type: ${data.type}, value: ${data.value}');
  //     });
  //     return '0';

  //     // final hash = await _authorApi.submitExtrinsic(extrinsic);
  //     // return convert.hex.encode(0);
  //   } catch (e, stackTrace) {
  //     print('Failed to transfer balance: $e');
  //     print('Failed to transfer balance: $stackTrace');
  //     throw Exception('Failed to transfer balance: $e');
  //   }
  // }

  // Generic method to submit any extrinsic
  Future<String> submitExtrinsic(String senderSeed, dynamic call) async {
    try {
      // Ensure provider is connected before proceeding
      if (_provider == null) {
        await initialize();
      }

      crypto.Keypair senderWallet = dilithiumKeypairFromMnemonic(senderSeed);

      // Get all necessary info for the transaction
      final runtimeVersion = await _stateApi!.getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;

      final block = await _provider!.send('chain_getBlock', []);
      final blockNumber = int.parse(block.result['block']['header']['number']);
      final blockHash = (await _provider!.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
      final genesisHash = (await _provider!.send('chain_getBlockHash', [0])).result.replaceAll('0x', '');
      final nonceResult = await _provider!.send('system_accountNextIndex', [senderWallet.ss58Address]);
      final nonce = int.parse(nonceResult.result.toString());

      // Encode call
      final resonanceApi = Resonance(_provider!);
      final transferCall = call.encode();

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

      // Create the extrinsic
      var extrinsic = ResonanceExtrinsicPayload(
        signer: Uint8List.fromList(senderWallet.addressBytes),
        method: transferCall,
        signature: signatureWithPublicKeyBytes,
        eraPeriod: 64,
        blockNumber: blockNumber,
        nonce: nonce,
        tip: 0,
      ).encodeResonance(resonanceApi.registry, ResonanceSignatureType.resonance);

      // Submit with retry logic
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          await _authorApi!.submitAndWatchExtrinsic(extrinsic, (data) async {
            print('Extrinsic type: ${data.type}, value: ${data.value}');
          });
          return '0'; // Success
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) rethrow;
          await Future.delayed(Duration(milliseconds: 500 * retryCount));

          // Refresh block info for retry
          final newBlock = await _provider!.send('chain_getBlock', []);
          final newBlockNumber = int.parse(newBlock.result['block']['header']['number']);
          final newBlockHash = (await _provider!.send('chain_getBlockHash', [])).result.replaceAll('0x', '');
          final newNonceResult = await _provider!.send('system_accountNextIndex', [senderWallet.ss58Address]);
          final newNonce = int.parse(newNonceResult.result.toString());

          // Recreate payload with new block info
          final newPayloadToSign = SigningPayload(
            method: transferCall,
            specVersion: specVersion,
            transactionVersion: transactionVersion,
            genesisHash: genesisHash,
            blockHash: newBlockHash,
            blockNumber: newBlockNumber,
            eraPeriod: 64,
            nonce: newNonce,
            tip: 0,
          );

          final newPayload = newPayloadToSign.encode(resonanceApi.registry);
          final newSignature = crypto.signMessage(keypair: senderWallet, message: newPayload);
          final newSignatureWithPublicKeyBytes = _combineSignatureAndPubkey(newSignature, senderWallet.publicKey);

          extrinsic = ResonanceExtrinsicPayload(
            signer: Uint8List.fromList(senderWallet.addressBytes),
            method: transferCall,
            signature: newSignatureWithPublicKeyBytes,
            eraPeriod: 64,
            blockNumber: newBlockNumber,
            nonce: newNonce,
            tip: 0,
          ).encodeResonance(resonanceApi.registry, ResonanceSignatureType.resonance);
        }
      }

      return '0';
    } catch (e) {
      throw Exception('Failed to submit extrinsic: $e');
    }
  }

  // Getter for provider (for services that need direct access)
  Provider? get provider => _provider;

  Future<void> logout() async {
    await _settingsService.clearAll();
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

  bool isValidSS58Address(String address) {
    try {
      final _ = crypto.ss58ToAccountId(s: address);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Helper function to convert bytes to hex string
  String bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  void dispose() {
    _connectionStatusController.close();
    // Dispose of the provider instance if it has a dispose/close method
    // _provider.close(); // If a close method exists
  }
}
