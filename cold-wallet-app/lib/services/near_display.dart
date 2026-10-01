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
  ///
  /// The JSON is re-indented from its own text, never decoded and re-encoded:
  /// a Dart `num` cannot hold every JSON number, and an amount the signer
  /// reads must be the amount the contract receives, digit for digit.
  static String argsText(Uint8List args) {
    if (args.isEmpty) return '(none)';
    final String text;
    try {
      text = utf8.decode(args, allowMalformed: false);
      json.decode(text);
    } on FormatException {
      return '0x${hex.encode(args)}';
    }
    final pretty = reindentJson(text);
    return isDisplaySafe(pretty, allowNewlines: true) ? pretty : '0x${hex.encode(args)}';
  }

  /// Re-indents [text], which must already be valid JSON, copying every token
  /// through verbatim. Only whitespace outside strings is changed.
  static String reindentJson(String text) {
    final out = StringBuffer();
    var depth = 0;
    var inString = false;
    var escaped = false;
    void newline() => out.write('\n${'  ' * depth}');

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        out.write(c);
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      switch (c) {
        case '"':
          inString = true;
          out.write(c);
        case '{' || '[':
          out.write(c);
          if (_closesImmediately(text, i)) {
            out.write(text[_nextNonSpace(text, i + 1)]);
            i = _nextNonSpace(text, i + 1);
          } else {
            depth++;
            newline();
          }
        case '}' || ']':
          depth--;
          newline();
          out.write(c);
        case ',':
          out.write(c);
          newline();
        case ':':
          out.write(': ');
        case ' ' || '\t' || '\n' || '\r':
          break;
        default:
          out.write(c);
      }
    }
    return out.toString();
  }

  static int _nextNonSpace(String text, int from) {
    var i = from;
    while (i < text.length && ' \t\n\r'.contains(text[i])) {
      i++;
    }
    return i;
  }

  /// Whether the bracket at [open] is followed by its closer, so `{}` and
  /// `[]` stay on one line.
  static bool _closesImmediately(String text, int open) {
    final next = _nextNonSpace(text, open + 1);
    if (next >= text.length) return false;
    return (text[open] == '{' && text[next] == '}') || (text[open] == '[' && text[next] == ']');
  }

  /// A string from the transaction — a method name, a key's method list —
  /// shown only when nothing in it can reorder or hide what is rendered;
  /// otherwise its bytes, as hex.
  static String safeText(String text) => isDisplaySafe(text) ? text : '0x${hex.encode(utf8.encode(text))}';

  /// Whether every character renders in place: no control characters, and
  /// none of the bidi or zero-width format characters that could reverse,
  /// join or hide the text around them.
  static bool isDisplaySafe(String text, {bool allowNewlines = false}) => text.runes.every((r) {
    if (allowNewlines && r == 0x0A) return true;
    if (r < 0x20 || (r >= 0x7F && r <= 0x9F)) return false;
    return !((r >= 0x200B && r <= 0x200F) ||
        (r >= 0x202A && r <= 0x202E) ||
        (r >= 0x2060 && r <= 0x2064) ||
        (r >= 0x2066 && r <= 0x2069) ||
        r == 0xFEFF);
  });

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

  /// A naming-convention hint, not a verdict on the request. NEAR account IDs
  /// do not encode a network: the `network` label comes from the requesting
  /// wallet, and this only notices when a sub-account's top-level name is the
  /// *other* network's customary one (`.near` on mainnet, `.testnet` on
  /// testnet). Top-level accounts (`near`, `registrar`), implicit accounts
  /// (64 hex, `0x` + 40 hex) and deterministic accounts (`0s` + 40 hex) carry
  /// no such convention and are never flagged. Only the labels
  /// [NearSigningRequest.supportedNetworks] admits reach here; anything else
  /// is a bug upstream and is reported, never passed over.
  static String? networkMismatch(NearTransaction tx, String network) {
    final otherTld = switch (network) {
      'mainnet' => '.testnet',
      'testnet' => '.near',
      _ => throw ArgumentError.value(network, 'network', 'not a supported NEAR network'),
    };
    final suspicious = [tx.signerId, tx.receiverId].where((id) => id.endsWith(otherTld)).toList();
    if (suspicious.isEmpty) return null;
    final plural = suspicious.length > 1;
    return 'The requesting wallet labelled this $network, but ${suspicious.join(' and ')} '
        '${plural ? 'end' : 'ends'} in $otherTld, the name usually used on ${_networkOf(otherTld)}. '
        'Account names do not prove a network; check which one your hot wallet is on before signing.';
  }

  static String _networkOf(String tld) => tld == '.near' ? 'mainnet' : 'testnet';
}
