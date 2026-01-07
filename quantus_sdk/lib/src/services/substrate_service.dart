import 'dart:async';
import 'dart:math';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/schrodinger/schrodinger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/resonance_extrinsic_payload.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:ss58/ss58.dart';
import 'package:quantus_sdk/src/extensions/address_extension.dart';

const crystalAlice = '//Crystal Alice';
const crystalBob = '//Crystal Bob';
const crystalCharlie = '//Crystal Charlie';

// equivalent to crypto.ss58ToAccountId(s: ss58Address)
Uint8List getAccountId32(String ss58Address) {
  return Address.decode(ss58Address).addressBytes;
}

class SubstrateService {
  static final SubstrateService _instance = SubstrateService._internal();
  factory SubstrateService() => _instance;
  SubstrateService._internal();

  final RpcEndpointService _rpcEndpointService = RpcEndpointService();
  final SettingsService _settingsService = SettingsService();

  Future<BigInt> getFee(Uint8List signedExtrinsic) async {
    try {
      final hexEncodedSignedExtrinsic = bytesToHex(signedExtrinsic);

      final result = await _rpcEndpointService.rpcTask((uri) async {
        final provider = Provider.fromUri(uri);
        return await provider.send('payment_queryInfo', [hexEncodedSignedExtrinsic, null]);
      });

      print('getFee: $result');
      if (result.error != null) {
        throw Exception('RPC Error: ${result.error}');
      }
      final partialFeeString = result.result['partialFee'] as String;
      final partialFee = BigInt.parse(partialFeeString);
      print('partialFee: $partialFee');
      return partialFee;
    } catch (e, s) {
      print('Error estimating fee: $e $s');
      throw Exception('Failed to estimate network fee: $e');
    }
  }

  Future<crypto.Keypair> _getUserWallet() async {
    final account = (await SettingsService().getActiveAccount())!;
    final keypair = await account.getKeypair();
    return keypair;
  }

  // Fetch balance of current user
  Future<BigInt> queryUserBalance() async {
    final keyPair = await _getUserWallet();
    final balance = await queryBalance(keyPair.ss58Address);
    print('user balance: $balance');
    return balance;
  }

  Future<BigInt> queryBalance(String address) async {
    try {
      final accountID = crypto.ss58ToAccountId(s: address);

      final accountInfo = await _rpcEndpointService.rpcTask((uri) async {
        final provider = Provider.fromUri(uri);
        final resonanceApi = Schrodinger(provider);
        return await resonanceApi.query.system.account(accountID);
      });

      print('user balance $address: ${accountInfo.data.free}');
      return accountInfo.data.free;
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

  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async {
    // We use a dummy signature for fee estimation to avoid prompting for password/device.
    // The node needs a properly formatted signed extrinsic to estimate fees, even if the signature is invalid.
    final extrinsic = await getExtrinsicPayload(account, call, isSigned: false);
    final fee = await getFee(extrinsic.payload);
    return ExtrinsicFeeData(fee: fee, blockHash: extrinsic.blockHash, blockNumber: extrinsic.blockNumber);
  }

  /// Submit a fully formatted extrinsic for block inclusion.
  /// The type will be changed to Extrinsic later
  /// Note: Copied from author API
  Future<Uint8List> _submitExtrinsic(Uint8List extrinsic) async {
    final params = ['0x${hex.encode(extrinsic)}'];

    final response = await _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      return await provider.send('author_submitExtrinsic', params);
    });

    print('submitExtrinsic response: ${response.result}');
    if (response.error != null) {
      throw Exception(response.error.toString());
    }

    final data = response.result as String;
    return Uint8List.fromList(hex.decode(data.substring(2)));
  }

  Future<Uint8List> submitExtrinsic(Account account, RuntimeCall call, {int maxRetries = 3}) async {
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

  Future<ExtrinsicData> getExtrinsicPayload(Account account, RuntimeCall call, {bool isSigned = true}) async {
    final [runtimeVersion, genesisHash, blockNumber, blockHash, nonce] = await Future.wait([
      _rpcEndpointService.rpcTask((uri) async {
        final provider = Provider.fromUri(uri);
        final stateApi = StateApi(provider);
        return await stateApi.getRuntimeVersion();
      }),
      _getGenesisHash(),
      _getBlockNumber(),
      _getBlockHash(),
      _getNextAccountNonceFromAddress(account.accountId),
    ]);

    final [specVersion, transactionVersion] = [runtimeVersion.specVersion, runtimeVersion.transactionVersion];
    final encodedCall = call.encode();

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

    final registry = await _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      return Schrodinger(provider).registry;
    });

    final payload = payloadToSign.encode(registry);

    if (isSigned) {
      final mnemonic = await account.getMnemonic();
      if (mnemonic == null) {
        throw Exception('Mnemonic not found for signing.');
      }
      final senderWallet = HdWalletService().keyPairAtIndex(mnemonic, account.index);

      final signature = crypto.signMessage(keypair: senderWallet, message: payload);
      final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(signature, senderWallet.publicKey);

      final extrinsic = ResonanceExtrinsicPayload(
        signer: Uint8List.fromList(senderWallet.addressBytes),
        method: encodedCall,
        signature: signatureWithPublicKeyBytes,
        eraPeriod: 64,
        blockNumber: blockNumber,
        nonce: nonce,
        tip: 0,
      ).encodeResonance(registry, ResonanceSignatureType.resonance);

      return ExtrinsicData(payload: extrinsic, blockNumber: blockNumber, blockHash: blockHash, nonce: nonce);
    } else {
      // Use a dummy signature for fee estimation
      // 7219 is the size of the Dilithium signature + public key
      final dummySignature = Uint8List(7219);
      final signerBytes = getAccountId32(account.accountId);

      final extrinsic = ResonanceExtrinsicPayload(
        signer: signerBytes,
        method: encodedCall,
        signature: dummySignature,
        eraPeriod: 64,
        blockNumber: blockNumber,
        nonce: nonce,
        tip: 0,
      ).encodeResonance(registry, ResonanceSignatureType.resonance);

      return ExtrinsicData(payload: extrinsic, blockNumber: blockNumber, blockHash: blockHash, nonce: nonce);
    }
  }

  Future<UnsignedTransactionData> getUnsignedTransactionPayload(Account account, RuntimeCall call) async {
    final accountIdBytes = crypto.ss58ToAccountId(s: account.accountId);

    final [runtimeVersion, genesisHash, blockNumber, blockHash, nonce] = await Future.wait([
      _rpcEndpointService.rpcTask((uri) async {
        final provider = Provider.fromUri(uri);
        final stateApi = StateApi(provider);
        return await stateApi.getRuntimeVersion();
      }),
      _getGenesisHash(),
      _getBlockNumber(),
      _getBlockHash(),
      _getNextAccountNonceFromAddress(account.accountId),
    ]);

    final [specVersion, transactionVersion] = [runtimeVersion.specVersion, runtimeVersion.transactionVersion];
    final encodedCall = call.encode();

    final payloadToSign = QuantusSigningPayload(
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

    final registry = await _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      return Schrodinger(provider).registry;
    });

    return UnsignedTransactionData(payloadToSign: payloadToSign, signer: accountIdBytes, registry: registry);
  }

  Future<Uint8List> submitExtrinsicWithExternalSignature(
    UnsignedTransactionData unsignedData,
    Uint8List signature,
    Uint8List publicKey,
  ) async {
    final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(signature, publicKey);

    final payload = unsignedData.payloadToSign;

    final extrinsic = ResonanceExtrinsicPayload(
      signer: unsignedData.signer,
      method: payload.method,
      signature: signatureWithPublicKeyBytes,
      eraPeriod: payload.eraPeriod,
      blockNumber: payload.blockNumber,
      nonce: payload.nonce,
      tip: payload.tip,
    ).encodeResonance(unsignedData.registry, ResonanceSignatureType.resonance);

    return await _submitExtrinsic(extrinsic);
  }

  Future<int> _getNextAccountNonceFromAddress(String address) async {
    final nonceResult = await _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      return await provider.send('system_accountNextIndex', [address]);
    });
    return int.parse(nonceResult.result.toString());
  }

  Future<dynamic> _getBlockHash() async {
    final result = await _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      return await provider.send('chain_getBlockHash', []);
    });
    return result.result.replaceAll('0x', '');
  }

  Future<dynamic> _getGenesisHash() async {
    final result = await _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      return await provider.send('chain_getBlockHash', [0]);
    });
    return result.result.replaceAll('0x', '');
  }

  Future<int> _getBlockNumber() async {
    final blockHeader = await _rpcEndpointService.rpcTask((uri) async {
      final provider = Provider.fromUri(uri);
      return await provider.send('chain_getHeader', []);
    });
    return int.parse(blockHeader.result['number']);
  }

  Provider? get provider {
    try {
      return Provider.fromUri(Uri.parse(_rpcEndpointService.bestEndpointUrl));
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    print('Log out!');
    await _settingsService.clearAll();
    await TaskmasterService().logout();
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
    // Dispose of the provider instance if it has a dispose/close method
    // _provider.close(); // If a close method exists
  }
}
