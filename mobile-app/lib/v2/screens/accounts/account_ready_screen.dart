import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final formattedAddress = AddressFormattingService.formatAddress(
      accountId,
      prefix: 8,
      ellipses: '.......',
      postFix: 10,
    );
    final appBarTitle = _appBarTitle(l10n);
    final headline = isWalletRelated ? appBarTitle : accountName;

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
                              border: Border.all(color: colors.success, width: _borderWidth),
                            ),
                            child: Icon(Icons.check_rounded, size: _checkIconSize, color: colors.success),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: text.paragraph?.copyWith(fontSize: 32, color: colors.textLightGray, height: 1.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (isWalletRelated) ...[
                        Text(
                          accountName,
                          textAlign: TextAlign.center,
                          style: text.transactionDetailRowLabel?.copyWith(color: colors.textTertiary),
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
                                    style: text.smallParagraph?.copyWith(
                                      color: colors.checksum,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  loading: () => const Loader(size: 14),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                            const SizedBox(height: 4),
                            Text(
                              formattedAddress.toLowerCase(),
                              textAlign: TextAlign.center,
                              style: text.transactionDetailRowValue?.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(
            label: l10n.accountReadyDone,
            onTap: () => _goHome(context),
            variant: ButtonVariant.primary,
          ),
        ),
      ),
    );
  }
}
