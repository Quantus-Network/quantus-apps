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
import 'package:quantus_sdk/src/services/connection_status.dart';
import 'package:quantus_sdk/src/services/provider_manager.dart';
import 'package:ss58/ss58.dart';

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

  final SettingsService _settingsService = SettingsService();
  static const Duration _defaultOpTimeout = Duration(seconds: 10);

  Stream<ConnectionStatus> get connectionStatus =>
      ProviderManager().connectionStatus;

  Future<void> initialize() async {
    await ProviderManager().ensureConnected();
  }

  Future<void> reconnect() async {
    await ProviderManager().reconnect();
  }

  Future<BigInt> getFee(Uint8List signedExtrinsic) async {
    try {
      // Convert encoded signed extrinsic to hex string
      final hexEncodedSignedExtrinsic = bytesToHex(signedExtrinsic);

      // Use provider.send to call the payment_queryInfo RPC with the signed extrinsic
      final result = await ProviderManager().withProvider((provider) async {
        return await provider.send('payment_queryInfo', [
          hexEncodedSignedExtrinsic,
          null,
        ]);
      }, operationTimeout: _defaultOpTimeout);

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
          e is TimeoutException) {}
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
      final result = await ProviderManager().withProvider((provider) async {
        final resonanceApi = Schrodinger(provider);
        final accountID = crypto.ss58ToAccountId(s: address);
        final accountInfo = await resonanceApi.query.system.account(accountID);
        return accountInfo.data.free;
      }, operationTimeout: _defaultOpTimeout);
      print('user balance $address: $result');
      return result;
    } catch (e, st) {
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

    final response = await ProviderManager().withProvider((provider) async {
      return await provider.send('author_submitExtrinsic', params);
    }, operationTimeout: _defaultOpTimeout);
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
    await initialize();

    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final extrinsicData = await getExtrinsicPayload(account, call);
        Uint8List extrinsic = extrinsicData.payload;

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
    final result = await ProviderManager().withProvider((provider) async {
      final resonanceApi = Schrodinger(provider);
      final mnemonic = await account.getMnemonic();
      if (mnemonic == null) {
        throw Exception('Mnemonic not found for signing.');
      }
      final senderWallet = HdWalletService().keyPairAtIndex(
        mnemonic,
        account.index,
      );
      final runtimeVersion = await StateApi(provider).getRuntimeVersion();
      final specVersion = runtimeVersion.specVersion;
      final transactionVersion = runtimeVersion.transactionVersion;
      var genesisHash = await _getGenesisHash();
      final encodedCall = call.encode();
      final values = await Future.wait([
        _getBlockNumber(),
        _getBlockHash(),
        _getNextAccountNonce(senderWallet),
      ]);
      final blockNumber = values[0] as int;
      final blockHash = values[1] as String;
      final nonce = values[2] as int;

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

      return ExtrinsicData(
        payload: extrinsic,
        blockNumber: blockNumber,
        blockHash: blockHash,
        nonce: nonce,
      );
    }, operationTimeout: const Duration(seconds: 12));

    return result;
  }

  Future<int> _getNextAccountNonce(Keypair senderWallet) async {
    final nonceResult = await ProviderManager().withProvider((provider) async {
      return await provider.send('system_accountNextIndex', [
        senderWallet.ss58Address,
      ]);
    }, operationTimeout: _defaultOpTimeout);
    final nonce = int.parse(nonceResult.result.toString());
    return nonce;
  }

  Future<dynamic> _getBlockHash() async {
    final result = await ProviderManager().withProvider((provider) async {
      return await provider.send('chain_getBlockHash', []);
    }, operationTimeout: _defaultOpTimeout);
    final blockHash = result.result;
    return blockHash.replaceAll('0x', '');
  }

  Future<dynamic> _getGenesisHash() async {
    final result = await ProviderManager().withProvider((provider) async {
      return await provider.send('chain_getBlockHash', [0]);
    }, operationTimeout: _defaultOpTimeout);
    final genesisHash = result.result;
    return genesisHash.replaceAll('0x', '');
  }

  Future<int> _getBlockNumber() async {
    final blockHeader = await ProviderManager().withProvider((provider) async {
      return await provider.send('chain_getHeader', []);
    }, operationTimeout: _defaultOpTimeout);
    final blockNumber = int.parse(blockHeader.result['number']);
    return blockNumber;
  }

  Provider? get provider => ProviderManager().provider;

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
    ProviderManager().dispose();
  }
}
