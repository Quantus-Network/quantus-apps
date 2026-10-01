import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Display rules for reviewing a NEAR transaction. Pure functions over the
/// decoded [NearTransaction], so they can be checked without the Rust bridge.
class NearDisplay {
  const NearDisplay._();

  static const nearDecimals = 24;
  static final BigInt _yoctoPerNear = BigInt.from(10).pow(nearDecimals);
  static final BigInt _gasPerTgas = BigInt.from(10).pow(12);

  /// Exact: every significant decimal is kept, so a signer never sees a
  /// rounded figure for what they are authorising.
  static String formatNear(BigInt yocto) {
    final whole = yocto ~/ _yoctoPerNear;
    var fraction = (yocto % _yoctoPerNear).toString().padLeft(nearDecimals, '0');
    fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }

  static String formatGas(BigInt gas) {
    if (gas % _gasPerTgas == BigInt.zero) return '${gas ~/ _gasPerTgas} Tgas';
    return '$gas gas';
  }

  /// Function-call arguments are JSON by convention; anything else is shown as hex.
  static String argsText(Uint8List args) {
    if (args.isEmpty) return '(none)';
    try {
      final decoded = json.decode(utf8.decode(args, allowMalformed: false));
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } on FormatException {
      return '0x${hex.encode(args)}';
    }
  }

  static String actionTitle(NearAction action) => switch (action.kind) {
    NearActionKind.transfer => 'SEND',
    NearActionKind.functionCall => 'CALL CONTRACT',
    NearActionKind.createAccount => 'CREATE ACCOUNT',
    NearActionKind.deployContract => 'DEPLOY CONTRACT',
    NearActionKind.stake => 'STAKE',
    NearActionKind.addKey => action.fullAccess ? 'ADD FULL ACCESS KEY' : 'ADD FUNCTION CALL KEY',
    NearActionKind.deleteKey => 'DELETE KEY',
    NearActionKind.deleteAccount => 'DELETE ACCOUNT',
  };

  /// Actions that change who controls the account or what code runs under it,
  /// rather than moving a stated amount. Shown in warning colour.
  static bool isDangerous(NearAction action) => switch (action.kind) {
    NearActionKind.addKey || NearActionKind.deleteKey || NearActionKind.deleteAccount => true,
    NearActionKind.deployContract || NearActionKind.stake => true,
    NearActionKind.transfer || NearActionKind.functionCall || NearActionKind.createAccount => false,
  };

  /// What the whole transaction does, in one line: the single action's title,
  /// or the count when there are several.
  static String headline(NearTransaction tx) {
    if (tx.actions.length == 1) return actionTitle(tx.actions.single);
    return '${tx.actions.length} ACTIONS';
  }

  /// The envelope's network is only a label the hot wallet attached; the
  /// account names are what the chain will see. Named accounts end in the
  /// network's top-level name, so a mismatch means one side is wrong.
  static String? networkMismatch(NearTransaction tx, String network) {
    final tld = switch (network) {
      'mainnet' => '.near',
      'testnet' => '.testnet',
      _ => null,
    };
    if (tld == null) return null;
    final mismatched = [tx.signerId, tx.receiverId].where((id) => _isNamed(id) && !id.endsWith(tld)).toList();
    if (mismatched.isEmpty) return null;
    return 'This request says $network, but ${mismatched.join(' and ')} '
        '${mismatched.length == 1 ? 'is not a' : 'are not'} $network account name'
        '${mismatched.length == 1 ? '' : 's'}. Check which network your hot wallet is on before signing.';
  }

  /// Implicit accounts (64 hex, or `0x` + 40 hex) belong to every network.
  static bool _isNamed(String accountId) => !RegExp(r'^([0-9a-f]{64}|0x[0-9a-f]{40})$').hasMatch(accountId);
}
