import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_menu_screen.dart';

/// Second add-Keystone screen: on-device instructions, then scans the device's
/// QR code to read the account address and saves the Keystone account.
class ConnectKeystoneScreen extends ConsumerStatefulWidget {
  const ConnectKeystoneScreen({super.key, required this.walletIndex, this.isNewWallet = false});

  final int walletIndex;
  final bool isNewWallet;

  @override
  ConsumerState<ConnectKeystoneScreen> createState() => _ConnectKeystoneScreenState();
}

class _ConnectKeystoneScreenState extends ConsumerState<ConnectKeystoneScreen> {
  final _accountsService = AccountsService();
  final _settingsService = SettingsService();
  final _substrateService = SubstrateService();

  bool _isSaving = false;
  String? _error;

  Future<void> _scan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage(), fullscreenDialog: true),
    );
    if (result == null || !mounted) return;
    final address = result.trim();
    if (!_substrateService.isValidSS58Address(address)) {
      setState(() => _error = ref.read(l10nProvider).invalidAddress);
      return;
    }
    await _save(address);
  }

  Future<void> _save(String address) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final nextIndex = await _settingsService.getNextFreeAccountIndex(widget.walletIndex);
      final account = Account(
        walletIndex: widget.walletIndex,
        index: nextIndex,
        name: 'Keystone Wallet',
        accountId: address,
        accountType: AccountType.keystone,
      );
      await _accountsService.addAccount(account);
      invalidateAccountProviders(ref);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AccountMenuScreen(initialAccount: account, isPostCreation: true)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    final sectionLabelStyle = text.labelData.copyWith(color: colors.textMuted);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.addKeystoneAppBarTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset('assets/v2/keystone_logo.png', width: 142, height: 32),
            const SizedBox(height: 24),
            Text(l10n.addKeystoneConnectTitle, style: text.titleHero.copyWith(color: colors.textContent)),
            const SizedBox(height: 8),
            Text(l10n.addKeystoneConnectSubtitle, style: text.body.copyWith(color: colors.textMuted)),
            const SizedBox(height: 40),
            Text(l10n.addKeystoneBeforeYouStart, style: sectionLabelStyle),
            const SizedBox(height: 12),
            _InstructionRow(
              iconAsset: 'assets/v2/keystone_arrow_line_down.svg',
              title: l10n.addKeystoneFirmwareTitle,
              subtitle: l10n.addKeystoneFirmwareSubtitle,
            ),
            const SizedBox(height: 24),
            const MenuDivider(),
            const SizedBox(height: 24),
            Text(l10n.addKeystoneOnYourKeystone, style: sectionLabelStyle),
            const SizedBox(height: 12),
            _InstructionRow(iconAsset: 'assets/v2/keystone_lock_simple_open.svg', title: l10n.addKeystoneStepUnlock),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: MenuDivider()),
            _InstructionRow(iconAsset: 'assets/v2/keystone_qr_code.svg', title: l10n.addKeystoneStepSelectQuantus),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: text.caption.copyWith(color: colors.semanticEmber)),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(
              label: l10n.addKeystoneReadyToScan,
              onTap: _isSaving ? null : _scan,
              isLoading: _isSaving,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              QuantusButton.simple(
                label: 'DEBUG: Use test address',
                variant: ButtonVariant.staged,
                onTap: _isSaving ? null : () => _save(AppConstants.debugTestAddress),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String? subtitle;

  const _InstructionRow({required this.iconAsset, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.bgSurface, shape: BoxShape.circle),
          child: SvgPicture.asset(iconAsset, width: 16, height: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.bodyLarge.copyWith(color: colors.textContent)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: text.caption.copyWith(color: colors.textMuted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
