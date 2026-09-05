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

  /// The slot this account derives from: its index, or the index its path
  /// names when that path follows the wallet's own template for [scheme]. Null
  /// for a path from somewhere else, which the wallet's numbering says nothing
  /// about.
  ///
  /// Read by rebuilding the template rather than matching a pattern, so the
  /// template stays defined in exactly one place.
  int? get templateIndex {
    if (index != null) return index;
    for (final segment in derivationPath.split('/')) {
      final candidate = int.tryParse(segment.replaceAll("'", ''));
      if (candidate != null && HdWalletService.pathForIndex(candidate, scheme) == derivationPath) return candidate;
    }
    return null;
  }

  /// Orders accounts by the slot they derive from, then scheme (current first),
  /// so a list reads as the seed's own sequence rather than the order the
  /// accounts happened to be added. A path this wallet does not number claims
  /// no slot, and sorts after the ones that do.
  static int compareByDerivation(ColdAccount a, ColdAccount b) {
    final left = a.templateIndex;
    final right = b.templateIndex;
    if (left != null && right != null) {
      final byIndex = left.compareTo(right);
      if (byIndex != 0) return byIndex;
      return _schemeSortOrder(a.scheme).compareTo(_schemeSortOrder(b.scheme));
    }
    if (left != null) return -1;
    if (right != null) return 1;
    return a.derivationPath.compareTo(b.derivationPath);
  }

  /// Sort position by scheme (current first). This is an ordering key, not the
  /// derivation path index (which is 0 for 87, 1 for 65).
  static int _schemeSortOrder(DilithiumScheme scheme) => scheme == DilithiumSchemeExtension.current ? 0 : 1;

  /// Scheme new accounts of this wallet open on: the current scheme once the
  /// wallet holds any account of it, otherwise the legacy one, so pre-existing
  /// wallets stay uniform unless the other scheme is chosen for an account.
  static DilithiumScheme walletScheme(Iterable<ColdAccount> accounts) =>
      accounts.any((a) => a.scheme == DilithiumSchemeExtension.current)
      ? DilithiumSchemeExtension.current
      : DilithiumSchemeExtension.legacy;

  /// The account [text] names as an index at [scheme], or null when it is not an
  /// index. The label follows the index, so the wallet's own numbering stays
  /// predictable.
  static ColdAccount? atIndexText(String text, {required DilithiumScheme scheme}) {
    final index = int.tryParse(text.trim());
    if (index == null || index < 0) return null;
    return ColdAccount(label: 'Account ${index + 1}', index: index, scheme: scheme);
  }

  /// The account at [path], or null when [path] is not a derivation path. The
  /// scheme is read from the path when it follows a template ([`.../1'`] for
  /// ML-DSA-65, [`.../0'`] for ML-DSA-87), otherwise [defaultScheme].
  static ColdAccount? atPath(String path, {required String label, required DilithiumScheme defaultScheme}) {
    final trimmed = path.trim();
    if (!HdWalletService.isValidPath(trimmed)) return null;
    return ColdAccount(label: label, path: trimmed, scheme: _schemeForPath(trimmed, defaultScheme));
  }

  static DilithiumScheme _schemeForPath(String path, DilithiumScheme fallback) {
    for (final scheme in DilithiumScheme.values) {
      for (final segment in path.split('/')) {
        final candidate = int.tryParse(segment.replaceAll("'", ''));
        if (candidate != null && HdWalletService.pathForIndex(candidate, scheme) == path) return scheme;
      }
    }
    return fallback;
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
