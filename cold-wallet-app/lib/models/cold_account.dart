import 'package:quantus_sdk/quantus_sdk.dart';

/// One account derived from the vault's single seed phrase.
///
/// Exactly one of [index] and [path] is set: an index fills the wallet's own
/// template, a path is taken verbatim so a seed created elsewhere can be used.
class ColdAccount {
  final String label;
  final int? index;
  final String? path;

  ColdAccount({required this.label, this.index, this.path}) {
    if ((index == null) == (path == null)) {
      throw ArgumentError('ColdAccount needs exactly one of index or path, got index: $index, path: $path');
    }
    if (index != null && index! < 0) throw ArgumentError('Account index cannot be negative: $index');
    if (path != null && !HdWalletService.isValidPath(path!)) {
      throw ArgumentError('Not a derivation path: $path');
    }
  }

  String get derivationPath => path ?? HdWalletService.pathForIndex(index!);

  /// The slot this account derives from: its index, or the index its path
  /// names when that path follows the wallet's own template. Null for a path
  /// from somewhere else, which the wallet's numbering says nothing about.
  ///
  /// Read by rebuilding the template rather than matching a pattern, so the
  /// template stays defined in exactly one place.
  int? get templateIndex {
    if (index != null) return index;
    for (final segment in derivationPath.split('/')) {
      final candidate = int.tryParse(segment.replaceAll("'", ''));
      if (candidate != null && HdWalletService.pathForIndex(candidate) == derivationPath) return candidate;
    }
    return null;
  }

  /// Orders accounts by the slot they derive from, so a list reads as the seed's
  /// own sequence rather than the order the accounts happened to be added. A
  /// path this wallet does not number claims no slot, and sorts after the ones
  /// that do.
  static int compareByDerivation(ColdAccount a, ColdAccount b) {
    final left = a.templateIndex;
    final right = b.templateIndex;
    if (left != null && right != null) return left.compareTo(right);
    if (left != null) return -1;
    if (right != null) return 1;
    return a.derivationPath.compareTo(b.derivationPath);
  }

  /// The account [text] names as an index, or null when it is not one. The
  /// label follows the index, so the wallet's own numbering stays predictable.
  static ColdAccount? atIndexText(String text) {
    final index = int.tryParse(text.trim());
    if (index == null || index < 0) return null;
    return ColdAccount(label: 'Account ${index + 1}', index: index);
  }

  /// The account at [path], or null when [path] is not a derivation path. Used
  /// for a seed created elsewhere, whose paths follow no template this wallet
  /// can number, so the label is supplied.
  static ColdAccount? atPath(String path, {required String label}) {
    if (!HdWalletService.isValidPath(path)) return null;
    return ColdAccount(label: label, path: path.trim());
  }

  factory ColdAccount.fromJson(Map<String, dynamic> json) =>
      ColdAccount(label: json['label'] as String, index: json['index'] as int?, path: json['path'] as String?);

  Map<String, dynamic> toJson() => {'label': label, if (index != null) 'index': index, if (path != null) 'path': path};
}
