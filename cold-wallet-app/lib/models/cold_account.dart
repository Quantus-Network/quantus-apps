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

  factory ColdAccount.fromJson(Map<String, dynamic> json) =>
      ColdAccount(label: json['label'] as String, index: json['index'] as int?, path: json['path'] as String?);

  Map<String, dynamic> toJson() => {'label': label, if (index != null) 'index': index, if (path != null) 'path': path};
}
