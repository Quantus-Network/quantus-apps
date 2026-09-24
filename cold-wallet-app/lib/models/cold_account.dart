import 'package:quantus_sdk/quantus_sdk.dart';

/// One account derived from the vault's single seed phrase.
///
/// Exactly one of [index] and [path] is set: an index fills the wallet's own
/// template for [scheme], a path is taken verbatim so a seed created elsewhere
/// can be used. [scheme] is the ML-DSA parameter set the key uses; accounts
/// stored before it was recorded are ML-DSA-87.
class ColdAccount {
  final String label;
  final int? index;
  final String? path;
  final DilithiumScheme scheme;

  ColdAccount({required this.label, this.index, this.path, required this.scheme}) {
    if ((index == null) == (path == null)) {
      throw ArgumentError('ColdAccount needs exactly one of index or path, got index: $index, path: $path');
    }
    if (index != null && index! < 0) throw ArgumentError('Account index cannot be negative: $index');
    if (path != null && !HdWalletService.isValidPath(path!)) {
      throw ArgumentError('Not a derivation path: $path');
    }
  }

  String get derivationPath => path ?? HdWalletService.pathForIndex(index!, scheme);

  /// Whether [other] derives the same key, whatever either is called.
  bool derivesSameKey(ColdAccount other) => derivationPath == other.derivationPath && scheme == other.scheme;

  ColdAccount withLabel(String label) => ColdAccount(label: label, index: index, path: path, scheme: scheme);

  /// The slot this account derives from: its index, or the index its path
  /// names when that path follows the wallet's own template for [scheme]. Null
  /// for a path from somewhere else, which the wallet's numbering says nothing
  /// about.
  ///
  /// Read by rebuilding the template rather than matching a pattern, so the
  /// template stays defined in exactly one place.
  int? get templateIndex => index ?? _templateIndexOf(derivationPath, scheme);

  static int? _templateIndexOf(String path, DilithiumScheme scheme) {
    for (final segment in path.split('/')) {
      final candidate = int.tryParse(segment.replaceAll("'", ''));
      if (candidate != null && HdWalletService.pathForIndex(candidate, scheme) == path) return candidate;
    }
    return null;
  }

  /// Scheme the signature type choice opens on for a new wallet or account.
  static const DilithiumScheme newAccountScheme = DilithiumScheme.mlDsa87;

  /// The account [text] names as an index at [scheme], or null when it is not an
  /// index. The label follows the index, so the wallet's own numbering stays
  /// predictable.
  static ColdAccount? atIndexText(String text, {required DilithiumScheme scheme}) {
    final index = int.tryParse(text.trim());
    if (index == null || index < 0) return null;
    return ColdAccount(label: 'Account ${index + 1}', index: index, scheme: scheme);
  }

  /// The account at [path], or null when [path] is not a derivation path. A
  /// last element of `0'` or `1'` names the scheme ([schemeOfPath]); any other
  /// path takes [defaultScheme], the user's own choice.
  static ColdAccount? atPath(String path, {required String label, required DilithiumScheme defaultScheme}) {
    final trimmed = path.trim();
    if (!HdWalletService.isValidPath(trimmed)) return null;
    return ColdAccount(label: label, path: trimmed, scheme: schemeOfPath(trimmed) ?? defaultScheme);
  }

  static const _schemeElements = {DilithiumScheme.mlDsa87: "0'", DilithiumScheme.mlDsa65: "1'"};

  /// The scheme a path's last element names — `0'` ML-DSA-87, `1'` ML-DSA-65,
  /// the convention of the wallet's own templates — or null for any other.
  static DilithiumScheme? schemeOfPath(String path) =>
      _schemeElements.entries.where((e) => e.value == path.trim().split('/').last).firstOrNull?.key;

  /// [path] rewritten to name [scheme] in its last element, when that element
  /// names a scheme at all; any other path is returned unchanged.
  static String pathAtScheme(String path, DilithiumScheme scheme) {
    if (schemeOfPath(path) == null) return path;
    final trimmed = path.trim();
    return '${trimmed.substring(0, trimmed.lastIndexOf('/') + 1)}${_schemeElements[scheme]}';
  }

  factory ColdAccount.fromJson(Map<String, dynamic> json) => ColdAccount(
    label: json['label'] as String,
    index: json['index'] as int?,
    path: json['path'] as String?,
    scheme: DilithiumSchemeExtension.fromStorageName(json['scheme'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    if (index != null) 'index': index,
    if (path != null) 'path': path,
    'scheme': scheme.storageName,
  };
}
