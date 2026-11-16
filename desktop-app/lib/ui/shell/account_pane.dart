import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The active account's balance in its card; its name and actions are in the
/// header above. On the encrypted account a notice says so, so it is never mistaken
/// for a transparent one.
class AccountPane extends ConsumerWidget {
  const AccountPane({super.key});

  /// The margin around the pane's content, which the header above it keeps.
  static const double padding = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return ref
        .watch(activeAccountProvider)
        .when(
          loading: () => const Center(child: Loader()),
          error: (_, _) => _message(context, l10n.accountsSheetFailedLoadActiveAccount),
          data: (active) =>
              active == null ? _message(context, l10n.homeNoActiveAccount) : _content(context, ref, active),
        );
  }

  Widget _message(BuildContext context, String message) {
    return Center(
      child: Text(message, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, DisplayAccount active) {
    final l10n = ref.watch(l10nProvider);
    final account = active.account;

    return Padding(
      padding: const EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BalanceCard(account: account),
          if (isEncryptedAccount(account)) ...[
            const SizedBox(height: 24),
            PrivateActivityNotice(
              title: l10n.createAccountEncryptedDefaultName,
              subtitle: l10n.privateSendSubtitle,
              showCard: true,
            ),
          ],
        ],
      ),
    );
  }
}
