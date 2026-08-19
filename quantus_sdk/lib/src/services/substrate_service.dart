import 'dart:async';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/generated/planck/planck.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/resonance_extrinsic_payload.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/utils/timing.dart';
import 'package:ss58/ss58.dart' hide Registry;
import 'package:quantus_sdk/src/utils/print.dart';

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

  String? _cachedGenesisHash;
  RuntimeVersion? _cachedRuntimeVersion;
  DateTime? _runtimeVersionFetchedAt;
  static const _runtimeVersionMaxAge = Duration(minutes: 5);

  void _clearChainCaches() {
    _cachedGenesisHash = null;
    _cachedRuntimeVersion = null;
    _runtimeVersionFetchedAt = null;
  }

  /// Runtime version only changes on runtime upgrades, so it is cached briefly.
  /// Send flows prefetch it on entry so payload builds hit the cache.
  Future<RuntimeVersion> getRuntimeVersion() async {
    final cached = _cachedRuntimeVersion;
    final fetchedAt = _runtimeVersionFetchedAt;
    if (cached != null && fetchedAt != null && DateTime.now().difference(fetchedAt) < _runtimeVersionMaxAge) {
      return cached;
    }
    final version = await _rpcEndpointService.providerTask((provider) => StateApi(provider).getRuntimeVersion());
    _cachedRuntimeVersion = version;
    _runtimeVersionFetchedAt = DateTime.now();
    return version;
  }

  Future<BigInt> getFee(Uint8List signedExtrinsic) async {
    try {
      final hexEncodedSignedExtrinsic = bytesToHex(signedExtrinsic);

      final result = await _rpcEndpointService.providerTask(
        (provider) => provider.send('payment_queryInfo', [hexEncodedSignedExtrinsic, null]),
      );

      if (result.error != null) {
        throw Exception('RPC Error: ${result.error}');
      }
      final partialFeeString = result.result['partialFee'] as String;
      return BigInt.parse(partialFeeString);
    } catch (e, s) {
      quantusPrint('Error estimating fee: $e $s');
      throw Exception('Failed to estimate network fee: $e');
    }
  }

  Future<crypto.Keypair> _getUserWallet() async {
    final account = (await SettingsService().getActiveRegularAccount())!;
    final keypair = await account.getKeypair();
    return keypair;
  }

  // Fetch balance of current user
  Future<BigInt> queryUserBalance() async {
    final keyPair = await _getUserWallet();
    final balance = await queryBalance(keyPair.ss58Address);
    quantusPrint('user balance: $balance');
    return balance;
  }

  Future<BigInt> queryBalance(String address) async {
    try {
      final accountID = crypto.ss58ToAccountId(s: address);
      final totalSw = Stopwatch()..start();

      final accountInfo = await _rpcEndpointService.providerTask((provider) async {
        final callSw = Stopwatch()..start();
        final result = await Planck(provider).query.system.account(accountID);
        printTiming('queryBalance call', callSw.elapsedMilliseconds);
        return result;
      });

      printTiming('queryBalance total', totalSw.elapsedMilliseconds);
      quantusPrint('user balance $address: ${accountInfo.data.free}');
      return accountInfo.data.free;
    } catch (e, st) {
      quantusPrint('Error querying balance: $e, $st');
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

    final response = await _rpcEndpointService.providerTask(
      (provider) => provider.send('author_submitExtrinsic', params),
    );

    quantusPrint('submitExtrinsic response: ${response.result}');
    if (response.error != null) {
      // A rejected extrinsic can mean a runtime upgrade landed while the cached
      // spec/genesis was still considered fresh — drop the caches so the next
      // payload is built against re-fetched chain state.
      _clearChainCaches();
      throw Exception(response.error.toString());
    }

    final data = response.result as String;
    return Uint8List.fromList(hex.decode(data.substring(2)));
  }

  // Utility method to submit and watch an extrinsic.
  // Good for debugging - overall direct fire and forget calls are more reliable.
  // ignore: unused_element
  Future<Uint8List> _submitExtrinsicAndWatch(Uint8List extrinsic) async {
    final params = ['0x${hex.encode(extrinsic)}'];

    // For debugging: calculate the hash locally since submitAndWatch returns a sub ID
    final txHash = Hasher.blake2b256.hash(extrinsic);
    final txHashHex = '0x${hex.encode(txHash)}';
    quantusPrint('Calculated Tx Hash: $txHashHex');

    // We don't await this because we want to return the hash immediately
    // but keep the listener running
    _rpcEndpointService.rpcTask((uri) async {
      final wsUri = uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws');
      quantusPrint('submitExtrinsic (Watch) to $wsUri');

      final provider = Provider.fromUri(wsUri);

      try {
        final subscription = await provider.subscribe('author_submitAndWatchExtrinsic', params);
        quantusPrint('Subscribed to extrinsic updates: ${subscription.id}');

        subscription.stream.listen((message) {
          quantusPrint('Extrinsic Status Update [${message.subscription}]: ${message.result}');

          // Check for error/invalid
          final result = message.result;
          if (result is Map &&
              (result.containsKey('invalid') || result.containsKey('dropped') || result.containsKey('error'))) {
            quantusPrint('Extrinsic FAILED/DROPPED: $result');
          }
        });
      } catch (e) {
        quantusPrint('Error watching extrinsic: $e');
      }

      // Keep alive for logs
      await Future.delayed(const Duration(seconds: 20));
    });

    return txHash;
  }

  Future<Uint8List> submitExtrinsic(Account account, RuntimeCall call, {int maxRetries = 3}) async {
    // Sign once and resubmit the exact same bytes on retry. Re-signing with a
    // fresh nonce can double spend when an earlier attempt already reached the
    // network despite a client-side error.
    final extrinsic = (await getExtrinsicPayload(account, call)).payload;
    final txHash = Hasher.blake2b256.hash(extrinsic);

    for (int attempt = 1; ; attempt++) {
      try {
        return await _submitExtrinsic(extrinsic);
      } catch (e) {
        if (_isAlreadySubmittedError(e, isRetry: attempt > 1)) {
          quantusPrint('Extrinsic 0x${hex.encode(txHash)} already known by network: $e');
          return txHash;
        }
        if (attempt >= maxRetries) {
          quantusPrint('Failed to submit extrinsic after $maxRetries attempts: $e');
          rethrow;
        }
        quantusPrint('Failed to submit extrinsic, retrying... attempt $attempt error: $e');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  // 'Already Imported' is hash-specific: a pool already holds this exact
  // transaction. 'outdated'/'stale' on a retry of identical bytes means an
  // earlier attempt was already included in a block.
  bool _isAlreadySubmittedError(Object e, {required bool isRetry}) {
    final message = e.toString().toLowerCase();
    if (message.contains('already imported')) return true;
    return isRetry && (message.contains('outdated') || message.contains('stale'));
  }

  /// Everything chain-dependent a signing payload needs, fetched in one
  /// parallel round trip. Genesis hash and runtime version come from cache
  /// when fresh, so usually only header, block hash and nonce hit the network.
  Future<({RuntimeVersion runtimeVersion, dynamic genesisHash, int blockNumber, dynamic blockHash, int nonce})>
  _getSigningContext(String accountId) async {
    final [runtimeVersion, genesisHash, blockNumber, blockHash, nonce] = await Future.wait<dynamic>([
      getRuntimeVersion(),
      _getGenesisHash(),
      _getBlockNumber(),
      _getBlockHash(),
      _getNextAccountNonceFromAddress(accountId),
    ]);
    return (
      runtimeVersion: runtimeVersion as RuntimeVersion,
      genesisHash: genesisHash,
      blockNumber: blockNumber as int,
      blockHash: blockHash,
      nonce: nonce as int,
    );
  }

  Future<ExtrinsicData> getExtrinsicPayload(Account account, RuntimeCall call, {bool isSigned = true}) async {
    final ctx = await _getSigningContext(account.accountId);
    final blockNumber = ctx.blockNumber;
    final blockHash = ctx.blockHash;
    final nonce = ctx.nonce;
    final encodedCall = call.encode();

    final payloadToSign = SigningPayload(
      method: encodedCall,
      specVersion: ctx.runtimeVersion.specVersion,
      transactionVersion: ctx.runtimeVersion.transactionVersion,
      genesisHash: ctx.genesisHash,
      blockHash: blockHash,
      blockNumber: blockNumber,
      eraPeriod: AppConstants.txMortalEraPeriodBlocks,
      nonce: nonce,
      tip: 0,
    );

    final registry = Registry();
    final payload = payloadToSign.encode(registry);

    if (isSigned) {
      final mnemonic = await account.getMnemonic();
      if (mnemonic == null) {
        throw Exception('Mnemonic not found for signing.');
      }
      final senderWallet = HdWalletService().keyPairAtIndex(mnemonic, account.index);

      final signature = senderWallet.sign(payload);
      final signatureWithPublicKeyBytes = _combineSignatureAndPubkey(signature, senderWallet.publicKey);

      final extrinsic = ResonanceExtrinsicPayload(
        signer: Uint8List.fromList(senderWallet.addressBytes),
        method: encodedCall,
        signature: signatureWithPublicKeyBytes,
        eraPeriod: AppConstants.txMortalEraPeriodBlocks,
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
        eraPeriod: AppConstants.txMortalEraPeriodBlocks,
        blockNumber: blockNumber,
        nonce: nonce,
        tip: 0,
      ).encodeResonance(registry, ResonanceSignatureType.resonance);

      return ExtrinsicData(payload: extrinsic, blockNumber: blockNumber, blockHash: blockHash, nonce: nonce);
    }
  }

  Future<UnsignedTransactionData> getUnsignedTransactionPayload(Account account, RuntimeCall call) async {
    final accountIdBytes = crypto.ss58ToAccountId(s: account.accountId);
    final ctx = await _getSigningContext(account.accountId);
    final encodedCall = call.encode();

    final payloadToSign = QuantusSigningPayload(
      method: encodedCall,
      specVersion: ctx.runtimeVersion.specVersion,
      transactionVersion: ctx.runtimeVersion.transactionVersion,
      genesisHash: ctx.genesisHash,
      blockHash: ctx.blockHash,
      blockNumber: ctx.blockNumber,
      eraPeriod: AppConstants.txMortalEraPeriodBlocks,
      nonce: ctx.nonce,
      tip: 0,
    );

    return UnsignedTransactionData(payloadToSign: payloadToSign, signer: accountIdBytes, registry: Registry());
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
    final nonceResult = await _rpcEndpointService.providerTask(
      (provider) => provider.send('system_accountNextIndex', [address]),
    );
    return int.parse(nonceResult.result.toString());
  }

  Future<dynamic> _getBlockHash() async {
    final result = await _rpcEndpointService.providerTask((provider) => provider.send('chain_getBlockHash', []));
    return result.result.replaceAll('0x', '');
  }

  /// Immutable per chain, so fetched once per app run.
  Future<dynamic> _getGenesisHash() async {
    final cached = _cachedGenesisHash;
    if (cached != null) return cached;
    final result = await _rpcEndpointService.providerTask((provider) => provider.send('chain_getBlockHash', [0]));
    final hash = result.result.replaceAll('0x', '') as String;
    _cachedGenesisHash = hash;
    return hash;
  }

  Future<int> _getBlockNumber() async {
    final blockHeader = await _rpcEndpointService.providerTask((provider) => provider.send('chain_getHeader', []));
    return int.parse(blockHeader.result['number']);
  }

  /// Returns the current best block number from the chain header.
  Future<int> getCurrentBlockNumber() => _getBlockNumber();

  Provider? get provider {
    try {
      return _rpcEndpointService.providerFor(_rpcEndpointService.bestEndpointUrl);
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    quantusPrint('Log out!');
    // Quiesce in-flight encrypted-account work (loads, sends) before wiping
    // anything: an operation still holding the old mnemonic-derived material
    // must not keep running — or persist state — past this point.
    await EncryptedAccountService.disposeAll();
    await _settingsService.clearAll();
    // Wormhole / encrypted-account files live outside SettingsService storage
    // and would otherwise leak balances into the next wallet session.
    await WormholeUtxoService.clearAllCaches();
    await EncryptedAccountService.clearAllPersistedState();
  }

  Future<String> generateMnemonic() async {
    try {
      // Generate a random entropy
      final random = Random.secure();
      final entropy = List<int>.generate(32, (_) => random.nextInt(256));
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
