import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/global_history_polling_service.dart';
import 'package:resonance_network_wallet/shell/desktop_nav_item.dart';
import 'package:resonance_network_wallet/shell/desktop_section.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';

class DesktopSidebar extends ConsumerStatefulWidget {
  final DesktopSection selectedSection;
  final ValueChanged<DesktopSection> onSectionSelected;

  const DesktopSidebar({super.key, required this.selectedSection, required this.onSectionSelected});

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(globalHistoryPollingServiceProvider).triggerManualRefresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  IconData _iconForSection(DesktopSection section) {
    switch (section) {
      case DesktopSection.home:
        return Icons.account_balance_wallet_outlined;
      case DesktopSection.activity:
        return Icons.history;
      case DesktopSection.receive:
        return Icons.arrow_downward;
      case DesktopSection.send:
        return Icons.arrow_upward;
      case DesktopSection.settings:
        return Icons.settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final radius = context.radiusV3;
    final l10n = ref.watch(l10nProvider);
    final activeAccountAsync = ref.watch(activeAccountProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: colors.bgVoid,
        border: Border(right: BorderSide(color: colors.borderHairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // App brand header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                SvgPicture.asset('assets/v2/uppercase_q.svg', width: 24, height: 24),
                const SizedBox(width: 12),
                Text('QUANTUS', style: text.titleScreen.copyWith(color: colors.textContent, letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Active account switcher row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              borderRadius: radius.mdBorder,
              onTap: () => openAccountsScreen(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: radius.mdBorder,
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Row(
                  children: [
                    activeAccountAsync.when(
                      data: (display) {
                        if (display == null) {
                          return const AccountBadge.icon(icon: Icons.person_outline, size: 32);
                        }
                        return AccountBadge(name: display.account.name, size: 32, isActive: true);
                      },
                      loading: () => const AccountBadge.icon(icon: Icons.person_outline, size: 32),
                      error: (_, _) => const AccountBadge.icon(icon: Icons.error_outline, size: 32),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeAccountAsync.value?.account.name ?? l10n.homeNoActiveAccount,
                            style: text.labelMonogram.copyWith(color: colors.textContent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            activeAccountAsync.value is MultisigDisplayAccount ? 'Multisig' : 'Account',
                            style: text.caption.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.unfold_more, size: 16, color: colors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final section in DesktopSection.values)
                  DesktopNavItem(
                    icon: _iconForSection(section),
                    label: section.label(l10n),
                    isSelected: widget.selectedSection == section,
                    onTap: () => widget.onSectionSelected(section),
                  ),
              ],
            ),
          ),
          // Bottom toolbar: Connection status & Manual Refresh button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.borderHairline)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? colors.semanticSage : colors.semanticEmber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnline ? 'Connected' : 'Offline',
                    style: text.caption.copyWith(color: isOnline ? colors.textMuted : colors.semanticEmber),
                  ),
                ),
                Tooltip(
                  message: l10n.desktopRefreshTooltip,
                  child: QuantusIconButton.ghost(
                    icon: Icons.refresh,
                    size: IconButtonSize.small,
                    isLoading: _isRefreshing,
                    onTap: _handleRefresh,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
