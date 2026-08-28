import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';

enum AccountReadyOverviewOrigin { accountCreated, walletCreated, walletImported }

class AccountReadyScreen extends ConsumerWidget {
  const AccountReadyScreen({super.key, required this.origin, required this.accountName, required this.accountId});

  final AccountReadyOverviewOrigin origin;
  final String accountName;
  final String accountId;

  static const _successRingSize = 78.0;
  static const _checkIconSize = 32.0;
  static const _borderWidth = 2.0;

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute<void>(builder: (_) => const HomeScreen()), (_) => false);
  }

  String _appBarTitle(AppLocalizations l10n) => switch (origin) {
    AccountReadyOverviewOrigin.accountCreated => l10n.accountReadyAccountCreated,
    AccountReadyOverviewOrigin.walletCreated => l10n.accountReadyWalletCreated,
    AccountReadyOverviewOrigin.walletImported => l10n.accountReadyWalletImported,
  };

  bool get isWalletRelated =>
      origin == AccountReadyOverviewOrigin.walletCreated || origin == AccountReadyOverviewOrigin.walletImported;

  bool get _showTwoAccountCards => origin == AccountReadyOverviewOrigin.walletCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final appBarTitle = _appBarTitle(l10n);
    final headline = isWalletRelated ? appBarTitle : accountName;
    final ctaLabel = _showTwoAccountCards ? l10n.accountReadyGoToWallet : l10n.accountReadyDone;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _goHome(context);
        }
      },
      child: ScaffoldBase(
        appBar: V2AppBar(title: appBarTitle, showBackButton: false),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: _successRingSize,
                            height: _successRingSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.semanticSage, width: _borderWidth),
                            ),
                            child: Icon(Icons.check_rounded, size: _checkIconSize, color: colors.semanticSage),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: text.titleSuccess.copyWith(color: colors.textContent),
                          ),
                          if (_showTwoAccountCards) ...[
                            const SizedBox(height: 4),
                            Text(
                              l10n.accountReadyTwoAccountsCreated,
                              textAlign: TextAlign.center,
                              style: text.body.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ],
                      ),
                      if (_showTwoAccountCards) ...[
                        const SizedBox(height: 40),
                        _WalletCreatedAccountCards(mainAccountName: accountName, l10n: l10n),
                      ] else ...[
                        const SizedBox(height: 32),
                        if (isWalletRelated) ...[
                          Text(
                            accountName,
                            textAlign: TextAlign.center,
                            style: text.caption.copyWith(color: colors.textMuted),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              ref
                                  .watch(checksumNameProvider(accountId))
                                  .when(
                                    data: (checksum) => Text(
                                      checksum,
                                      textAlign: TextAlign.center,
                                      style: text.body.copyWith(color: colors.semanticLilac),
                                    ),
                                    loading: () => const Loader(size: 14),
                                    error: (_, _) => const SizedBox.shrink(),
                                  ),
                              const SizedBox(height: 4),
                              Text(
                                AddressFormattingService.formatAddress(
                                  accountId,
                                  prefix: 8,
                                  ellipses: '.......',
                                  postFix: 10,
                                ).toLowerCase(),
                                textAlign: TextAlign.center,
                                style: text.dataAddressLarge.copyWith(color: colors.textContent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(
            key: const Key(E2EKeys.accountReadyDoneButton),
            label: ctaLabel,
            onTap: () => _goHome(context),
            variant: ButtonVariant.primary,
          ),
        ),
      ),
    );
  }
}

class _WalletCreatedAccountCards extends StatelessWidget {
  const _WalletCreatedAccountCards({required this.mainAccountName, required this.l10n});

  final String mainAccountName;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final encryptedName = l10n.createAccountEncryptedDefaultName;

    return Column(
      children: [
        _AccountPreviewCard(
          leading: AccountBadge(name: mainAccountName),
          title: mainAccountName,
          description: l10n.accountReadyMainAccountDescription,
        ),
        const SizedBox(height: 14),
        _AccountPreviewCard(
          leading: const EncryptedLockBadge(),
          title: encryptedName,
          description: l10n.accountReadyEncryptedAccountDescription,
        ),
      ],
    );
  }
}

class _AccountPreviewCard extends StatelessWidget {
  const _AccountPreviewCard({required this.leading, required this.title, required this.description});

  final Widget leading;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.headingRow.copyWith(color: colors.textContent)),
                const SizedBox(height: 4),
                Text(description, style: text.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
