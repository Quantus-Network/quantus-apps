import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ImportWalletScreenV2 extends ConsumerStatefulWidget {
  const ImportWalletScreenV2({super.key, this.walletIndex = 0});

  final int walletIndex;

  @override
  ConsumerState<ImportWalletScreenV2> createState() => _ImportWalletScreenV2State();
}

/// Renders the seed phrase as `x` characters while keeping the real text
/// intact, since [TextField.obscureText] is unsupported for multiline fields.
///
/// The mask must keep the same character count as the real text so the caret
/// and selection positions stay accurate while typing.
class _ObscuringMnemonicController extends TextEditingController {
  bool obscured = true;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (!obscured) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    return TextSpan(style: style, text: 'x' * text.length);
  }
}

class _ImportWalletScreenV2State extends ConsumerState<ImportWalletScreenV2> {
  final _controller = _ObscuringMnemonicController();
  final _focusNode = FocusNode();
  final _buttonKey = GlobalKey();
  final _settingsService = SettingsService();
  final _accountsService = AccountsService();
  final _discoveryService = AccountDiscoveryService(HdWalletService(), SubstrateService());
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_revealButton);
  }

  void _revealButton() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = _buttonKey.currentContext;
        if (mounted && ctx != null) {
          // ignore: use_build_context_synchronously
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

  bool get _hasInput => _controller.text.trim().isNotEmpty;

  Future<void> _import() async {
    final accounts = ref.read(accountsProvider).value ?? <Account>[];
    final mnemonic = _controller.text.trim();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!mnemonic.startsWith('//')) {
        final words = mnemonic.split(' ').where((w) => w.isNotEmpty).toList();
        if (words.length != 12 && words.length != 24) {
          throw Exception(ref.read(l10nProvider).importWalletValidationError);
        }
      }

      final key = HdWalletService().keyPairAtIndex(mnemonic, 0);
      await _settingsService.setMnemonic(mnemonic, widget.walletIndex);
      await _accountsService.addAccount(
        Account(
          walletIndex: widget.walletIndex,
          index: 0,
          name: 'Account ${accounts.length + 1}',
          accountId: key.ss58Address,
        ),
      );

      if (!HdWalletService.isDevAccount(mnemonic)) {
        await _discoverAccounts(mnemonic);
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      _settingsService.setReferralCheckCompleted();
      _settingsService.setExistingUserSeenPromoVideo();

      if (ref.read(remoteConfigProvider).enableRemoteNotifications && widget.walletIndex == 0) {
        ref.read(firebaseMessagingServiceProvider).registerDeviceIfPossible();
      } else if (ref.read(remoteConfigProvider).enableRemoteNotifications && widget.walletIndex > 0) {
        ref.read(firebaseMessagingServiceProvider).insertNewAddress(key.ss58Address);
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _discoverAccounts(String mnemonic) async {
    try {
      final discovered = await _discoveryService.discoverAccounts(mnemonic: mnemonic, walletIndex: widget.walletIndex);
      final existing = (await _accountsService.getAccounts()).map((e) => e.accountId).toSet();
      for (final account in discovered) {
        if (!existing.contains(account.accountId)) {
          await _accountsService.addAccount(account);
        }
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
    } catch (e, st) {
      quantusDebugPrint('error discovering accounts: $e');
      TelemetryService().sendError('Error discovering accounts', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final fieldTextStyle = text.smallTitle?.copyWith(color: colors.checksum, fontWeight: FontWeight.w400);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.importWalletAppBarTitle),
      mainContent: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(l10n.importWalletDescription, style: text.smallParagraph?.copyWith(color: colors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                height: 202,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderButton, width: 1),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 36),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: (_) => setState(() {}),
                        style: fieldTextStyle,
                        decoration: InputDecoration.collapsed(
                          hintText: l10n.importWalletHint,
                          hintStyle: fieldTextStyle?.copyWith(color: colors.textSecondary),
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _controller.obscured = !_controller.obscured),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          _controller.obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 22,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: text.detail?.copyWith(color: colors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: _buttonKey,
          label: l10n.importWalletButton,
          onTap: _import,
          isLoading: _isLoading,
          isDisabled: !_hasInput,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_revealButton);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
