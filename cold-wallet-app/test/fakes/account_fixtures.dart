import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

const testMnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

final one = ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87);
final two = ColdAccount(label: 'Account 2', index: 1, scheme: DilithiumScheme.mlDsa87);
final legacy65 = ColdAccount(label: 'Old account', index: 1, scheme: DilithiumScheme.mlDsa65);
final custom65 = ColdAccount(label: 'Elsewhere', path: "m/44'/1'/0'", scheme: DilithiumScheme.mlDsa65);

/// Key derivation needs the native library, which unit tests do not load, so
/// each account stands in for its address by what the key derives from. The
/// path's hash at both ends keeps the shortened forms apart.
String fakeAddress(ColdAccount a) {
  final tag = a.derivationPath.hashCode.toRadixString(36);
  return 'qz$tag${a.scheme.storageName}:${a.derivationPath}:$tag';
}

/// Presents [accounts] as an unlocked wallet without opening a vault.
List<Override> accountOverrides(List<ColdAccount> accounts) => [
  accountsProvider.overrideWith((ref) => accounts),
  addressesProvider.overrideWith((ref) => {for (final a in ref.watch(accountsProvider)) fakeAddress(a): a}),
  checksumNameProvider.overrideWith((ref, address) async => 'phrase'),
];

Widget coldApp(Widget home) => Builder(
  builder: (context) => MaterialApp(theme: coldTheme(context), home: home),
);

/// A first route with an "open" button that pushes [screen], so a screen that
/// pops or replaces itself can be observed doing so.
Widget launcher(Widget screen) => Builder(
  builder: (context) => Scaffold(
    body: TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: const Text('open'),
    ),
  ),
);

Finder quantusIcon(QuantusIcons icon) => find.byWidgetPredicate((w) => w is QuantusIcon && w.icon == icon);

Finder coldIcon(ColdIcons icon) => find.byWidgetPredicate((w) => w is ColdIcon && w.icon == icon);
