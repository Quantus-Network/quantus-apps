import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/show_recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';

class SelectWalletForRecoveryPhraseScreen extends ConsumerStatefulWidget {
  const SelectWalletForRecoveryPhraseScreen({super.key});

  @override
  ConsumerState<SelectWalletForRecoveryPhraseScreen> createState() => _SelectWalletForRecoveryPhraseScreenState();
}

class _SelectWalletForRecoveryPhraseScreenState extends ConsumerState<SelectWalletForRecoveryPhraseScreen> {
  String _walletLabel(int walletIndex) {
    return 'Wallet ${walletIndex + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return ScaffoldBase(
      appBar: WalletAppBar(title: 'Select Wallet'),
      child: accountsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.themeColors.circularLoader)),
        error: (error, _) => Center(
          child: Text(
            'Failed to load wallets: $error',
            style: context.themeText.smallParagraph?.copyWith(color: Colors.white70),
          ),
        ),
        data: (accounts) {
          final walletIndices = getNonHardwareWalletIndices(accounts);
          
          if (walletIndices.isEmpty) {
            return Center(
              child: Text(
                'No wallets with recovery phrases found.',
                style: context.themeText.smallParagraph?.copyWith(color: Colors.white70),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18),
            itemCount: walletIndices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 22),
            itemBuilder: (context, index) {
              final walletIndex = walletIndices[index];
              return _buildWalletItem(walletIndex);
            },
          );
        },
      ),
    );
  }

  Widget _buildWalletItem(int walletIndex) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShowRecoveryPhraseScreen(walletIndex: walletIndex),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: context.isTablet ? 16 : 12, horizontal: 18),
        decoration: ShapeDecoration(
          color: context.themeColors.buttonGlass,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(_walletLabel(walletIndex), style: context.themeText.smallParagraph),
            Icon(Icons.arrow_forward_ios, size: context.themeSize.settingMenuIconSize),
          ],
        ),
      ),
    );
  }
}
