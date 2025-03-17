import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' as rust;
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:ss58/ss58.dart' as ss58;
import 'package:convert/convert.dart';

/// Implementation of KeyPair for Dilithium post-quantum cryptography
class DilithiumKeyPair implements KeyPair {
  @override
  late int ss58Format;
  rust.KeyPair _rustKeyPair;

  @override
  // TODO: implement address
  String get address => throw UnimplementedError();

  @override
  Uint8List bytes([bool compressed = true]) => Uint8List.fromList(_publicKey.encode());

  @override
  Future<KeyPair> fromMnemonic(String uri, [String? password]) {
    // TODO: implement fromMnemonic
    throw UnimplementedError();
  }

  @override
  KeyPair fromSeed(Uint8List seed) {
    // TODO: implement fromSeed
    throw UnimplementedError();
  }

  @override
  Future<KeyPair> fromUri(String uri, [String? password]) {
    // TODO: implement fromUri
    throw UnimplementedError();
  }

  @override
  // TODO: implement isLocked
  bool get isLocked => throw UnimplementedError();

  @override
  // TODO: implement keyPairType
  KeyPairType get keyPairType => throw UnimplementedError();

  @override
  void lock() {
    throw UnimplementedError();
  }

  @override
  // TODO: implement publicKey
  PublicKey get publicKey => throw UnimplementedError();

  @override
  // TODO: implement rawAddress
  String get rawAddress => throw UnimplementedError();

  @override
  Uint8List sign(Uint8List message) {
    // TODO: implement sign
    throw UnimplementedError();
  }

  @override
  Future<void> unlockFromMnemonic(String mnemonic, [String? password]) {
    // TODO: implement unlockFromMnemonic
    throw UnimplementedError();
  }

  @override
  void unlockFromSeed(Uint8List seed) {
    // TODO: implement unlockFromSeed
  }

  @override
  Future<void> unlockFromUri(String uri, [String? password]) {
    // TODO: implement unlockFromUri
    throw UnimplementedError();
  }

  @override
  bool verify(Uint8List message, Uint8List signature) {
    // TODO: implement verify
    throw UnimplementedError();
  }
}
