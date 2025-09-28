import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/schrodinger/schrodinger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/extensions/account_extension.dart';
import 'package:quantus_sdk/src/resonance_extrinsic_payload.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:ss58/ss58.dart';

enum ConnectionStatus { connecting, connected, disconnected, error }

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

class ExtrinsicData {
  Uint8List payload;
  int blockNumber;
  String blockHash;
  int nonce;
  ExtrinsicData({
    required this.payload,
    required this.blockHash,
    required this.blockNumber,
    required this.nonce,
  });
}

class ExtrinsicFeeData {
  BigInt fee;
  ExtrinsicData extrinsicData;
  ExtrinsicFeeData({required this.fee, required this.extrinsicData});
}

class SubstrateService {
  static final SubstrateService _instance = SubstrateService._internal();
  factory SubstrateService() => _instance;
  SubstrateService._internal();

  Provider? _provider;
  StateApi? _stateApi;
  static const String _rpcEndpoint = AppConstants.rpcEndpoint;
  final SettingsService _settingsService = SettingsService();

  // Add StreamController for connection status
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  // Expose the stream
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  Future<void> initialize() async {
    // Only create the provider if it hasn't been created yet
    // If it exists, assume it's already connected or will attempt to reconnect automatically.
    if (_provider == null) {
      _provider = Provider.fromUri(Uri.parse(_rpcEndpoint));
      // Initialize APIs with the new provider
      _stateApi = StateApi(_provider!);
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

    // Attempt to connect the new provider with timeout
    try {
      _connectionStatusController.add(ConnectionStatus.connecting);
      await _provider!.connect().timeout(networkTimeout);
      _connectionStatusController.add(ConnectionStatus.connected);
      print('New provider connected successfully during reconnect.');
    } catch (e) {
      _connectionStatusController.add(
        ConnectionStatus.disconnected,
      ); // Or error
      print('Failed to recreate/reconnect provider: $e');
      if (e is TimeoutException) {
        throw Exception(
          'Failed to reconnect to the network: Connection timed out.',
        );
      } else {
        throw Exception('Failed to reconnect to the network: $e');
      }
    }
  }

  Future<BigInt> getFee(Uint8List signedExtrinsic) async {
    try {
      // Convert encoded signed extrinsic to hex string
      final hexEncodedSignedExtrinsic = bytesToHex(signedExtrinsic);

      // Use provider.send to call the payment_queryInfo RPC with the signed extrinsic
      final result = await _provider!.send('payment_queryInfo', [
        hexEncodedSignedExtrinsic,
        null,
      ]); // null for block hash

      // Parse the result to get the partialFee
      // The result structure is typically {'partialFee': '...'} for this RPC
      print('getFee: $result');
      final partialFeeString = result.result['partialFee'] as String;
      final partialFee = BigInt.parse(partialFeeString);

      print('partialFee: $partialFee');

      return partialFee;
    } catch (e, s) {
      // If a network error occurs here, update the connection status
      if (e.toString().contains('WebSocketChannelException') ||
          e is SocketException ||
          e is TimeoutException) {
        _connectionStatusController.add(ConnectionStatus.disconnected);
      }
      print('Error estimating fee: $e $s');
      throw Exception('Failed to estimate network fee: $e');
    }
  }

  Future<crypto.Keypair> _getUserWallet() async {
    final account = (await SettingsService().getActiveAccount())!;
    final keypair = await account.getKeypair();
    return keypair;
  }

  // @Deprecated('Use Account.getKeypair() instead')
  // Future<DilithiumWalletInfo> generateWalletFromSeed(
  //   String seedPhrase,
  //   Account account,
  // ) async {
  //   try {
  //     final keypair = HdWalletService().keyPairAtIndex(
  //       seedPhrase,
  //       account.index,
  //     );
  //     return DilithiumWalletInfo.fromKeyPair(keypair, walletName: 'Account 1');
  //   } catch (e) {
  //     throw Exception('Failed to generate wallet: $e');
  //   }
  // }

  // Fetch balance of current user
  Future<BigInt> queryUserBalance() async {
    final keyPair = await _getUserWallet();
    final balance = await queryBalance(keyPair.ss58Address);
    print('user balance: $balance');
    return balance;
  }

  Future<BigInt> queryBalance(String address) async {
    try {
      // Create Resonance API instance
      final resonanceApi = Schrodinger(_provider!);
      // Account from SS58 address
      final accountID = crypto.ss58ToAccountId(s: address);

      // Retrieve Account Balance
      final accountInfo = await resonanceApi.query.system.account(accountID);

      print('user balance $address: ${accountInfo.data.free}');

      // Get the free balance
      return accountInfo.data.free;
    } catch (e, st) {
      // If a network error occurs here, update the connection status
      if (e.toString().contains('WebSocketChannelException') ||
          e is SocketException ||
          e is TimeoutException) {
        _connectionStatusController.add(ConnectionStatus.disconnected);
      }
      print('Error querying balance: $e, $st');
      throw Exception('Failed to query balance: $e');
    }
  }

  Uint8List _combineSignatureAndPubkey(List<int> signature, List<int> pubkey) {
    final result = Uint8List(signature.length + pubkey.length);
    result.setAll(0, signature);
    result.setAll(signature.length, pubkey);
    return result;
  }

  // Legacy method - supports CLI addresses and Miner App
  // The mobile app should use @HdWalletService for everything.
  crypto.Keypair nonHDdilithiumKeypairFromMnemonic(String senderSeed) {
    return crypto.generateKeypair(mnemonicStr: senderSeed);
  }

  Future<ExtrinsicFeeData> getFeeForCall(
    Account account,
    RuntimeCall call,
  ) async {
    final extrinsic = await getExtrinsicPayload(account, call);
    final fee = await getFee(extrinsic.payload);
    return ExtrinsicFeeData(fee: fee, extrinsicData: extrinsic);
  }

  /// Submit a fully formatted extrinsic for block inclusion.
  /// The type will be changed to Extrinsic later
  /// Note: Copied from author API
  Future<Uint8List> _submitExtrinsic(Uint8List extrinsic) async {
    final List<dynamic> params = ['0x${hex.encode(extrinsic)}'];

    final response = await _provider!.send('author_submitExtrinsic', params);
    // same hash - not the final extrinsic hash
    print('submitExtrinsic response: ${response.result}');

    if (response.error != null) {
      throw Exception(response.error.toString());
    }

    final data = response.result as String;
    return Uint8List.fromList(hex.decode(data.substring(2)));
  }

  Future<Uint8List> submitExtrinsic(
    Account account,
    RuntimeCall call, {
    int maxRetries = 3,
  }) async {
    if (_provider == null) {
      await initialize();
    }

    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final extrinsicData = await getExtrinsicPayload(account, call);
        Uint8List extrinsic = extrinsicData.payload;

        // final result = await _authorApi!.submitExtrinsic(extrinsic);
        final result = await _submitExtrinsic(extrinsic);

        print('result: $result');

        return result;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('Failed to submit extrinsic after $maxRetries retries: $e');
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
    throw Exception('Failed to submit extrinsic after $maxRetries retries.');
  }

  Future<ExtrinsicData> getExtrinsicPayload(
    Account account,
    RuntimeCall call,
  ) async {
    final resonanceApi = Schrodinger(_provider!);
    final mnemonic = await account.getMnemonic();
    if (mnemonic == null) {
      throw Exception('Mnemonic not found for signing.');
    }
    final senderWallet = HdWalletService().keyPairAtIndex(
      mnemonic,
      account.index,
    );
    final runtimeVersion = await _stateApi!.getRuntimeVersion();
    final specVersion = runtimeVersion.specVersion;
    final transactionVersion = runtimeVersion.transactionVersion;
    var genesisHash = await _getGenesisHash();
    final encodedCall = call.encode();
    final [blockNumber, blockHash, nonce] = await Future.wait([
      _getBlockNumber(),
      _getBlockHash(),
      _getNextAccountNonce(senderWallet),
    ]);

    final payloadToSign = SigningPayload(
      method: encodedCall,
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
    final signature = crypto.signMessage(
      keypair: senderWallet,
      message: payload,
    );
    // for testing failed transactions - use the bad signature.
    // var badSignature = Uint8List(signature.length); // 0 list

    final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(
      signature,
      senderWallet.publicKey,
    );

    final extrinsic = ResonanceExtrinsicPayload(
      signer: Uint8List.fromList(senderWallet.addressBytes),
      method: encodedCall,
      signature: signatureWithPublicKeyBytes,
      eraPeriod: 64,
      blockNumber: blockNumber,
      nonce: nonce,
      tip: 0,
    ).encodeResonance(resonanceApi.registry, ResonanceSignatureType.resonance);

    return ExtrinsicData(
      payload: extrinsic,
      blockNumber: blockNumber,
      blockHash: blockHash,
      nonce: nonce,
    );
  }

  Future<int> _getNextAccountNonce(Keypair senderWallet) async {
    final nonceResult = await _provider!.send('system_accountNextIndex', [
      senderWallet.ss58Address,
    ]);
    final nonce = int.parse(nonceResult.result.toString());
    return nonce;
  }

  Future<dynamic> _getBlockHash() async {
    final result = await _provider!.send('chain_getBlockHash', []);
    final blockHash = result.result;
    return blockHash.replaceAll('0x', '');
  }

  Future<dynamic> _getGenesisHash() async {
    final result = await _provider!.send('chain_getBlockHash', [0]);
    final genesisHash = result.result;
    return genesisHash.replaceAll('0x', '');
  }

  Future<int> _getBlockNumber() async {
    final blockHeader = await _provider!.send('chain_getHeader', []);
    final blockNumber = int.parse(blockHeader.result['number']);
    return blockNumber;
  }

  // Getter for provider (for services that need direct access)
  Provider? get provider => _provider;

  Future<void> logout() async {
    print('Log out!');
    await _settingsService.clearAll();
  }

  Future<String> generateMnemonic() async {
    try {
      // Generate a random entropy
      final entropy = List<int>.generate(
        32,
        (i) => Random.secure().nextInt(256),
      );
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
