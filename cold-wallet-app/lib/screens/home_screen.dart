import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/account_avatar.dart';
import 'package:quantus_cold_wallet/components/anchored_menu.dart';
import 'package:quantus_cold_wallet/components/offline_pill.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/accounts_screen.dart';
import 'package:quantus_cold_wallet/screens/scan_transaction_screen.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final online = ref.watch(isOnlineProvider);

    return ScaffoldBase(
      appBar: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 22),
        child: Row(
          children: [
            Builder(
              builder: (anchor) => _HeaderPill(
                onTap: () => _openSwitcher(context, anchor, ref),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Image.asset('assets/v2/uppercase_q.png', width: 32, height: 32),
                    QuantusIcon(QuantusIcons.caretDown, size: 20, color: colors.textContent),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _HeaderPill(
              width: 44,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: QuantusIcon(QuantusIcons.gear, size: 20, color: colors.textContent),
            ),
          ],
        ),
      ),
      mainContent: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuantusIcon(
                    QuantusIcons.wifiSlash,
                    size: 54,
                    color: online ? colors.semanticEmber : colors.semanticSage,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    online ? 'Not Safe to Sign' : 'Ready to sign',
                    style: text.titleHero.copyWith(color: colors.textContent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    online
                        ? 'You overrode the network lock. Switch your connections off.'
                        : 'Offline. Nothing can reach this device.',
                    style: text.bodyLarge.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (!online) const OfflinePill(),
          const SizedBox(height: 92),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Scan Transaction',
          icon: QuantusIcon(QuantusIcons.scan, size: 20, color: colors.textVoid),
          iconPlacement: IconPlacement.leading,
          padding: coldButtonPadding,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanTransactionScreen())),
        ),
      ),
    );
  }

  void _openSwitcher(BuildContext context, BuildContext anchor, WidgetRef ref) {
    final addresses = ref.read(addressesProvider);
    showAnchoredMenu(
      context,
      anchor: anchor,
      groups: [
        [
          for (final (index, entry) in addresses.entries.indexed)
            AnchoredMenuItem(
              label: entry.value.label,
              subtitle: shortAddress(entry.key),
              leading: AccountAvatar(label: entry.value.label, size: 30),
              isSelected: index == 0,
              onTap: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ShowKeyScreen(address: entry.key))),
            ),
        ],
        [
          AnchoredMenuItem(
            label: 'Manage accounts',
            isMuted: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),
        ],
      ],
    );
  }
}

/// 44pt glass pill (Figma Home header): the account switcher and the gear.
class _HeaderPill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double? width;

  const _HeaderPill({required this.child, required this.onTap, this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassButtonBase(
        buttonHeight: 44,
        buttonWidth: width,
        borderRadius: BorderRadius.circular(22),
        padding: EdgeInsets.symmetric(horizontal: width == null ? 12 : 0),
        child: Center(child: child),
      ),
    );
  }
}
