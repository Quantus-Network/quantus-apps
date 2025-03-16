import 'package:polkadart/polkadart.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart' as convert;

import 'generated/resonance/resonance.dart';
import 'generated/resonance/types/sp_runtime/multiaddress/multi_address.dart'
    as multi_address;
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
  static const String _rpcEndpoint =
      'ws://127.0.0.1:9944'; // Replace with actual endpoint

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
      final accountInfo =
          await resonanceApi.query.system.account(account.pubkey);
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

  Future<String> balanceTransfer(
      String mnemonic, String targetAddress, double amount) async {
    try {
      final polkadot = Resonance(_provider);

      final wallet = await KeyPair.sr25519.fromMnemonic(mnemonic);
      print('Sender\' wallet: ${wallet.address}');

      // Get information necessary to build a proper extrinsic
      final runtimeVersion = await polkadot.rpc.state.getRuntimeVersion();
      final currentBlockNumber = (await polkadot.query.system.number()) - 1;
      final currentBlockHash =
          await polkadot.query.system.blockHash(currentBlockNumber);
      final genesisHash = await polkadot.query.system.blockHash(0);
      final nonce = await polkadot.rpc.system.accountNextIndex(wallet.address);

      // Make the encoded call
      final multiAddress =
          const multi_address.$MultiAddress().id(wallet.publicKey.bytes);
      final transferCall = polkadot.tx.balances
          .transferKeepAlive(dest: multiAddress, value: BigInt.one);
      final encodedCall = transferCall.encode();

      // Make the payload
      final payload = SigningPayload(
              method: encodedCall,
              specVersion: runtimeVersion.specVersion,
              transactionVersion: runtimeVersion.transactionVersion,
              genesisHash: encodeHex(genesisHash),
              blockHash: encodeHex(currentBlockHash),
              blockNumber: currentBlockNumber,
              eraPeriod: 64,
              nonce: nonce,
              tip: 0)
          .encode(polkadot.registry);

      // Sign the payload and build the final extrinsic
      final signature = wallet.sign(payload);
      final extrinsic = ExtrinsicPayload(
        signer: wallet.bytes(),
        method: encodedCall,
        signature: signature,
        eraPeriod: 64,
        blockNumber: currentBlockNumber,
        nonce: nonce,
        tip: 0,
      ).encode(polkadot.registry, SignatureType.sr25519);

      // Send the extrinsic to the blockchain
      final author = AuthorApi(_provider);
      await author.submitAndWatchExtrinsic(extrinsic, (data) {
        print('data: $data');
      });
      return 'OK';
    } catch (e) {
      print(e);
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
      final entropy =
          List<int>.generate(32, (i) => Random.secure().nextInt(256));
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
