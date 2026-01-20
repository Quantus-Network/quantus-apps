import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/pull_funds_confirmation_sheet.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/snackbar_extensions.dart';

class EmergencyButton extends ConsumerWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final activeDisplayAccount = ref.read(activeAccountProvider).value;
        if (activeDisplayAccount is EntrustedDisplayAccount) {
          final accounts = ref.read(accountsProvider).value;
          final guardianAccount = accounts?.firstWhereOrNull(
            (a) => a.accountId == activeDisplayAccount.account.parentAccountId,
          );

          if (guardianAccount != null) {
            if (context.mounted) {
              showPullFundsConfirmationSheet(
                context,
                activeDisplayAccount.account.accountId,
                guardianAccount,
                () async {
                  try {
                    final highSecurityService = ref.read(highSecurityServiceProvider);
                    await highSecurityService.pullAllFunds(activeDisplayAccount.account.accountId, guardianAccount);

                    if (context.mounted) {
                      context.showSuccessSnackbar(
                        title: 'Success',
                        message: 'Emergency funds pull initiated successfully',
                      );
                    }
                  } catch (e) {
                    print('Error: Failed to pull funds: $e');
                    if (context.mounted) {
                      context.showErrorSnackbar(title: 'Error', message: 'Failed to pull funds: $e');
                    }
                  }
                },
              );
            }
          } else {
            print('Error: Guardian account not found on this device');
            if (context.mounted) {
              context.showErrorSnackbar(title: 'Error', message: 'Guardian account not found on this device');
            }
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Color(0xFF0AD4F6),
                Color(0x26FFFFFF), // #FFFFFF with 15% opacity
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            margin: const EdgeInsets.all(1), // Creates the border effect
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 1.0),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 17,
                children: [
                  SizedBox(width: 30, height: 30, child: Image.asset('assets/high_security/big_red_button_icon.png')),
                  const SizedBox(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'IN CASE OF EMERGENCY\n',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              height: 1.40,
                            ),
                          ),
                          TextSpan(
                            text: 'PULL ALL FUNDS FROM THIS ACCOUNT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w300,
                              height: 1.40,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
