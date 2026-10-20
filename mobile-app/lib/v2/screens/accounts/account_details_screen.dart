import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/address_details_card.dart';
import 'package:resonance_network_wallet/v2/components/share_account_button.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.accountDetailsTitle),
      mainContent: AddressDetailsCard(accountId: accountId),
      bottomContent: ScaffoldBaseBottomContent(
        child: ShareAccountButton(onTap: () => shareAccountDetails(context, accountId)),
      ),
    );
  }
}
