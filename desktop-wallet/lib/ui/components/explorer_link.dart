import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

Uri explorerTransactionUri(String extrinsicHash) =>
    Uri.parse('${AppConstants.explorerEndpoint}/transactions/$extrinsicHash');

Future<void> openExplorerTransaction(String extrinsicHash) => launchUrl(explorerTransactionUri(extrinsicHash));

class ExplorerLink extends StatelessWidget {
  final String extrinsicHash;
  final String label;

  const ExplorerLink({super.key, required this.extrinsicHash, required this.label});

  @override
  Widget build(BuildContext context) {
    return QuantusButton.simple(
      label: label,
      variant: ButtonVariant.underline,
      width: null,
      icon: const Icon(Icons.open_in_new_rounded, size: 14),
      iconPlacement: IconPlacement.trailing,
      onTap: () => openExplorerTransaction(extrinsicHash),
    );
  }
}
