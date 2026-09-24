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

  /// Scheme every new cold wallet account uses.
  static const DilithiumScheme newAccountScheme = DilithiumScheme.mlDsa87;

  /// The new account [text] names as an index, or null when it is not an index.
  /// The label follows the index, so the wallet's own numbering stays
  /// predictable.
  static ColdAccount? atIndexText(String text) {
    final index = int.tryParse(text.trim());
    if (index == null || index < 0) return null;
    return ColdAccount(label: 'Account ${index + 1}', index: index, scheme: newAccountScheme);
  }

  /// The account at [path], or null when [path] is not a derivation path.
  ///
  /// A path that follows a scheme's template names that scheme (`.../1'` is
  /// ML-DSA-65, `.../0'` is ML-DSA-87), so an existing account can be added
  /// back by its path and derive the same key. Any other path is a new account
  /// at [newAccountScheme].
  static ColdAccount? atPath(String path, {required String label}) {
    final trimmed = path.trim();
    if (!HdWalletService.isValidPath(trimmed)) return null;
    return ColdAccount(label: label, path: trimmed, scheme: _schemeForPath(trimmed) ?? newAccountScheme);
  }

  static DilithiumScheme? _schemeForPath(String path) =>
      DilithiumScheme.values.where((scheme) => _templateIndexOf(path, scheme) != null).firstOrNull;

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
