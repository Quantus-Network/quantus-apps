import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/account_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/create_account_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final NumberFormattingService _formattingService = NumberFormattingService();

  bool _isCreatingAccount = false;

  Future<void> _createNewAccount() async {
    setState(() {
      _isCreatingAccount = true;
    });
    try {
      await Navigator.push<bool?>(
        context,
        MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
      );
      // Providers will automatically refresh when a new account is added
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingAccount = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      decorations: [
        Positioned(
          right: -40,
          top: MediaQuery.of(context).size.height * 0.3,
          child: const Sphere(variant: 2, size: 194),
        ),
        const Positioned(
          left: -40,
          bottom: 0,
          child: Sphere(variant: 7, size: 240.681),
        ),
      ],
      appBar: 'Your Accounts',
      child: Column(
        children: [
          Expanded(child: _buildAccountsList()),

          Button(
            variant: ButtonVariant.glass,
            label: 'Create New Account',
            onPressed: _isCreatingAccount ? null : _createNewAccount,
          ),

           SizedBox(height: context.themeSize.bottomButtonSpacing)
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    final accountsAsync = ref.watch(accountsProvider);
    final activeAccountAsync = ref.watch(activeAccountProvider);

    return accountsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.themeColors.circularLoader,
        ),
      ),
      error: (error, _) => Center(
        child: Text(
          'Failed to load accounts: $error',
          style: context.themeText.smallParagraph?.copyWith(
            color: Colors.white70,
          ),
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return Center(
            child: Text(
              'No accounts found.',
              style: context.themeText.smallParagraph?.copyWith(
                color: Colors.white70,
              ),
            ),
          );
        }

        return activeAccountAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (error, _) => Center(
            child: Text(
              'Failed to load active account: $error',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          data: (activeAccount) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              itemCount: accounts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 25),
              itemBuilder: (context, index) {
                final account = accounts[index];
                final bool isActive =
                    account.accountId == activeAccount?.accountId;
                return _buildAccountListItem(account, isActive, index);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAccountListItem(Account account, bool isActive, int index) {
    return InkWell(
      onTap: () async {
        await ref
            .read(activeAccountProvider.notifier)
            .setActiveAccount(account);
        if (mounted) Navigator.pop(context);
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isTablet ? 20 : 8,
                    vertical: 8,
                  ),
                  decoration: ShapeDecoration(
                    color: isActive
                        ? context.themeColors.surfaceActive
                        : context.themeColors.surface,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1,
                        color: context.themeColors.borderLight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final balanceAsync = ref.watch(
                              balanceProviderFamily(account.accountId),
                            );

                            return FutureBuilder<String>(
                              future: _checksumService.getHumanReadableName(
                                account.accountId,
                              ),
                              builder: (context, checksumSnapshot) {
                                final humanChecksum =
                                    checksumSnapshot.data ?? '';

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: context.themeText.paragraph
                                          ?.copyWith(
                                            color: isActive
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                    ),
                                    Text(
                                      humanChecksum,
                                      style: context.themeText.detail?.copyWith(
                                        color: isActive
                                            ? context.themeColors.checksum
                                            : context.themeColors.checksumDarker,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          context.isTablet
                                              ? account.accountId
                                              // ignore: lines_longer_than_80_chars
                                              : AddressFormattingService.formatAddress(
                                                  account.accountId,
                                                ),
                                          style: context.themeText.detail
                                              ?.copyWith(
                                                color: isActive
                                                    ? context
                                                          .themeColors
                                                          .darkGray
                                                    : context
                                                          .themeColors
                                                          .textMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    balanceAsync.when(
                                      loading: () => Text(
                                        'loading balance...',
                                        style: context.themeText.detail
                                            ?.copyWith(
                                              color: isActive
                                                  ? context.themeColors.darkGray
                                                  : context.themeColors.light,
                                            ),
                                      ),
                                      error: (error, _) => Text(
                                        'error loading',
                                        style: context.themeText.detail
                                            ?.copyWith(
                                              color: isActive
                                                  ? context.themeColors.darkGray
                                                  : context
                                                        .themeColors
                                                        .textPrimary,
                                            ),
                                      ),
                                      data: (balance) => Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: _formattingService
                                                  .formatBalance(balance),
                                              style: context.themeText.smallParagraph
                                                  ?.copyWith(
                                                    color: isActive
                                                        ? context
                                                              .themeColors
                                                              .darkGray
                                                        : context
                                                              .themeColors
                                                              .textPrimary,
                                                  ),
                                            ),
                                            TextSpan(
                                              text:
                                                  ' ${AppConstants.tokenSymbol}',
                                              style: context.themeText.detail
                                                  ?.copyWith(
                                                    color: isActive
                                                        ? context
                                                              .themeColors
                                                              .darkGray
                                                        : context
                                                              .themeColors
                                                              .textPrimary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: SvgPicture.asset(
                  'assets/settings_icon_off.svg',
                  width: context.isTablet ? 28 : 21,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () async {
                  // Get current data from providers
                  final balanceAsync = ref.read(
                    balanceProviderFamily(account.accountId),
                  );
                  final checksumName = await _checksumService
                      .getHumanReadableName(account.accountId);

                  balanceAsync.when(
                    loading: () {
                      // Show loading or handle appropriately
                    },
                    error: (error, _) {
                      // Handle error
                    },
                    data: (balance) async {
                      if (!mounted) return;
                      await Navigator.push<bool?>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccountSettingsScreen(
                            account: account,
                            balance: _formattingService.formatBalance(
                              balance,
                              addSymbol: true,
                            ),
                            checksumName: checksumName,
                          ),
                        ),
                      );
                      // Providers will automatically refresh if needed
                    },
                  );
                },
              ),
            ],
          ),

          Positioned(
            // calculating the middle point
            top:
                (context.themeSize.accountListItemHeight / 2) -
                (context.themeSize.accountListItemLogoWidth / 2),
            left: (context.themeSize.accountListItemLogoWidth / 2) * -1,
            child: AccountGradientImage(
              accountId: account.accountId,
              width: context.themeSize.accountListItemLogoWidth,
              height: context.themeSize.accountListItemLogoWidth,
            ),
          ),
        ],
      ),
    );
  }
}
