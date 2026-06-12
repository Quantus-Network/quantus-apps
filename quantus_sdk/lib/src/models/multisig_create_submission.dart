import 'package:flutter/foundation.dart';

/// Resolved nonce and predicted address for a new multisig creation.
@immutable
class MultisigCreationParams {
  const MultisigCreationParams({required this.nonce, required this.address});

  final BigInt nonce;
  final String address;
}

/// Thrown when no free nonce is found within the search limit.
class MultisigNonceExhaustedException implements Exception {
  MultisigNonceExhaustedException({required this.maxAttempts});

  final int maxAttempts;

  @override
  String toString() => 'No available multisig nonce found within $maxAttempts attempts';
}

/// Thrown when the predicted multisig address already exists on-chain.
class MultisigAlreadyExistsException implements Exception {
  MultisigAlreadyExistsException(this.address);

  final String address;

  @override
  String toString() => 'Multisig already exists at $address';
}

/// Thrown when the creator cannot cover pallet fee and network fee.
class MultisigInsufficientBalanceException implements Exception {
  MultisigInsufficientBalanceException({required this.balance, required this.required});

  final BigInt balance;
  final BigInt required;

  @override
  String toString() => 'Insufficient balance for multisig creation: have $balance, need $required';
}
