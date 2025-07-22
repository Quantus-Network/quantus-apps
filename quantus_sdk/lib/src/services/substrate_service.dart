import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/resonance/resonance.dart';
import 'package:quantus_sdk/generated/resonance/types/sp_runtime/multiaddress/multi_address.dart'
    as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/extensions/account_extension.dart';
import 'package:quantus_sdk/src/resonance_extrinsic_payload.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:ss58/ss58.dart';

enum ConnectionStatus { connecting, connected, disconnected, error }

class DilithiumWalletInfo {
  final crypto.Keypair keypair;
  final String accountId;
  final String? mnemonic;
  final String walletName;
  DilithiumWalletInfo({
    required this.keypair,
    required this.accountId,
    this.mnemonic,
    required this.walletName,
  });

  factory DilithiumWalletInfo.fromKeyPair(
    crypto.Keypair keypair, {
    required String walletName,
    String? mnemonic,
  }) {
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
  static final SubstrateService _instance = SubstrateService._internal();
  factory SubstrateService() => _instance;
  SubstrateService._internal();

  Provider? _provider;
  StateApi? _stateApi;
  AuthorApi? _authorApi;
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

  Future<BigInt> getFee(
    String senderAddress,
    String recipientAddress,
    BigInt amount,
  ) async {
    try {
      final resonanceApi = Resonance(_provider!);
      final multiDest = const multi_address.$MultiAddress().id(
        getAccountId32(recipientAddress),
      );

      // Retrieve sender's mnemonic and generate keypair
      // Assuming senderAddress corresponds to the current wallet's account ID
      crypto.Keypair senderWallet = await _getUserWallet();

      // Get necessary info for the transaction (similar to balanceTransfer)
      final runtimeVersion = await _stateApi!.getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;

      final block = await _provider!.send('chain_getBlock', []);
      final blockNumber = int.parse(block.result['block']['header']['number']);

      final blockHash = (await _provider!.send(
        'chain_getBlockHash',
        [],
      )).result.replaceAll('0x', '');
      final genesisHash = (await _provider!.send('chain_getBlockHash', [
        0,
      ])).result.replaceAll('0x', '');

      // Get the next nonce for the sender
      final nonceResult = await _provider!.send('system_accountNextIndex', [
        senderWallet.ss58Address,
      ]);
      print('nonceResult: ${nonceResult.result} ${senderWallet.ss58Address}');
      final nonce = int.parse(nonceResult.result.toString());

      // Create the call for fee estimation
      final runtimeCall = resonanceApi.tx.balances.transferKeepAlive(
        dest: multiDest,
        value: amount,
      );
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
      final signature = crypto.signMessage(
        keypair: senderWallet,
        message: payload,
      );

      // Construct the signed extrinsic payload (Resonance specific)
      final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(
        signature,
        senderWallet.publicKey,
      ); // Reuse helper

      final signedExtrinsic =
          ResonanceExtrinsicPayload(
            signer: Uint8List.fromList(
              senderWallet.addressBytes,
            ), // Use signer address bytes
            method: transferCall, // The encoded call method
            signature: signatureWithPublicKeyBytes, // The signature
            eraPeriod: 64, // Must match SigningPayload
            blockNumber: blockNumber, // Must match SigningPayload
            nonce: nonce, // Must match SigningPayload
            tip: 0, // Must match SigningPayload
          ).encodeResonance(
            resonanceApi.registry,
            ResonanceSignatureType.resonance,
          );

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
      print('partialFeeString: $partialFeeString');
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
    final account = await SettingsService().getActiveAccount();
    final keypair = await account.getKeypair();
    return keypair;
  }

  @Deprecated('Use Account.getKeypair() instead')
  Future<DilithiumWalletInfo> generateWalletFromSeed(
    String seedPhrase,
    Account account,
  ) async {
    try {
      final keypair = HdWalletService().keyPairAtIndex(
        seedPhrase,
        account.index,
      );
      return DilithiumWalletInfo.fromKeyPair(keypair, walletName: 'Account 1');
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
      if (e.toString().contains('WebSocketChannelException') ||
          e is SocketException ||
          e is TimeoutException) {
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

  @Deprecated('Use Account.getKeypair() instead')
  crypto.Keypair dilithiumKeypairFromMnemonic(String senderSeed) {
    // This method is now simplified to support legacy calls or testing.
    // It defaults to deriving the key for account index 0.
    // For specific accounts, use HdWalletService().keyPairAtIndex(mnemonic, index).
    if (senderSeed.startsWith('//')) {
      // Handle test seeds
      return crypto.generateKeypair(mnemonicStr: senderSeed);
    }
    return HdWalletService().keyPairAtIndex(senderSeed, 0);
  }

  Future<StreamSubscription<ExtrinsicStatus>> submitExtrinsic(
    Account account,
    RuntimeCall call, {
    void Function(ExtrinsicStatus)? onStatus,
    int maxRetries = 3,
  }) async {
    if (_provider == null) {
      await initialize();
    }

    final mnemonic = await account.getMnemonic();
    if (mnemonic == null) {
      throw Exception('Mnemonic not found for signing.');
    }
    final senderWallet = HdWalletService().keyPairAtIndex(
      mnemonic,
      account.index,
    );

    final resonanceApi = Resonance(_provider!);

    final runtimeVersion = await _stateApi!.getRuntimeVersion();
    final specVersion = runtimeVersion.specVersion;
    final transactionVersion = runtimeVersion.transactionVersion;
    final genesisHash = (await _provider!.send('chain_getBlockHash', [
      0,
    ])).result.replaceAll('0x', '');
    final encodedCall = call.encode();

    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final block = await _provider!.send('chain_getBlock', []);
        final blockNumber = int.parse(
          block.result['block']['header']['number'],
        );
        final blockHash = (await _provider!.send(
          'chain_getBlockHash',
          [],
        )).result.replaceAll('0x', '');
        final nonceResult = await _provider!.send('system_accountNextIndex', [
          senderWallet.ss58Address,
        ]);
        final nonce = int.parse(nonceResult.result.toString());

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
        final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(
          signature,
          senderWallet.publicKey,
        );

        final extrinsic =
            ResonanceExtrinsicPayload(
              signer: Uint8List.fromList(senderWallet.addressBytes),
              method: encodedCall,
              signature: signatureWithPublicKeyBytes,
              eraPeriod: 64,
              blockNumber: blockNumber,
              nonce: nonce,
              tip: 0,
            ).encodeResonance(
              resonanceApi.registry,
              ResonanceSignatureType.resonance,
            );

        return _authorApi!.submitAndWatchExtrinsic(
          extrinsic,
          onStatus ?? (data) {},
        );
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

  // Getter for provider (for services that need direct access)
  Provider? get provider => _provider;

  Future<void> logout() async {
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
