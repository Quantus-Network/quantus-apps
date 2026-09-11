import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mainnet_migration_provider.dart';
import 'package:resonance_network_wallet/services/mainnet_migration_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/receive/receive_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/onboarding_background.dart';

/// Shown once to wallets that predate mainnet: a checking page while the
/// testnet lookup runs, the page written for what this wallet did there, and
/// a closing page once the wallet is kept.
class MainnetMigrationScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinished;

  const MainnetMigrationScreen({super.key, required this.onFinished});

  @override
  ConsumerState<MainnetMigrationScreen> createState() => _MainnetMigrationScreenState();
}

class _MainnetMigrationScreenState extends ConsumerState<MainnetMigrationScreen> {
  /// Keeps the checking page from flashing past when testnet answers at once.
  static const _checkingMinimum = Duration(milliseconds: 1500);
  static const _pageTurn = Duration(milliseconds: 450);

  final _pages = PageController();
  final _checkingShown = Future<void>.delayed(_checkingMinimum);

  /// Debug builds hold the checking page until an outcome is picked.
  late bool _armed = !ref.read(debugMainnetMigrationProvider);
  bool _creating = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _turnTo(int page) => _pages.animateToPage(page, duration: _pageTurn, curve: Curves.easeInOutCubic);

  Future<void> _showOutcome() async {
    _armed = false;
    await _checkingShown;
    if (mounted) await _turnTo(1);
  }

  void _pickOutcome(String? outcome) {
    ref.read(forcedTestnetOutcomeProvider.notifier).state = outcome;
    ref.invalidate(testnetStatusProvider);
    _armed = true;
  }

  Future<void> _keep(TestnetUserKind? kind) async {
    try {
      await ref.read(mainnetMigrationServiceProvider).markDone();
    } catch (e) {
      quantusPrint('Mainnet migration completion not saved: $e');
      if (mounted) context.showErrorToaster(message: ref.read(l10nProvider).mainnetMigrationSaveFailed('$e'));
      return;
    }
    TelemetryService().sendEvent('mainnet_migration_done', parameters: {'testnet_user': kind?.name ?? 'unknown'});
    if (mounted) await _turnTo(2);
  }

  void _getTokens() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiveScreen()));
    widget.onFinished();
  }

  Future<void> _createNewWallet({required bool checkFailed}) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await showQuantusDialog(
      context,
      title: l10n.mainnetMigrationCreateDialogTitle,
      body: checkFailed ? l10n.mainnetMigrationCreateDialogUncheckedAdvice : l10n.mainnetMigrationCreateDialogBody,
      banner: checkFailed
          ? QuantusBanner(
              tone: BannerTone.glacier,
              leading: const Text('?'),
              label: l10n.mainnetMigrationCreateDialogUncheckedTitle,
              message: l10n.mainnetMigrationCreateDialogUncheckedBody,
            )
          : null,
      actionLabel: l10n.mainnetMigrationCreateDialogConfirm,
      cancelLabel: l10n.mainnetMigrationCreateDialogCancel,
      cancelIsPrimary: checkFailed,
    );
    if (!confirmed || !mounted) return;
    TelemetryService().sendEvent('mainnet_migration_new_wallet');
    setState(() => _creating = true);
    await createSoftwareWalletFlow(context, ref);
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(testnetStatusProvider, (_, status) {
      if (_armed && !status.isLoading) _showOutcome();
    });
    final l10n = ref.watch(l10nProvider);
    // Watched here so the check runs while the checking page is still showing.
    final status = ref.watch(testnetStatusProvider);

    return PageView(
      key: const Key(E2EKeys.mainnetMigrationScreen),
      controller: _pages,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _CheckingPage(l10n: l10n, onPickOutcome: ref.watch(debugMainnetMigrationProvider) ? _pickOutcome : null),
        _OutcomePage(
          l10n: l10n,
          status: status,
          creating: _creating,
          onKeep: _keep,
          onCreateNewWallet: _createNewWallet,
        ),
        _AllSetPage(l10n: l10n, onGetTokens: _getTokens, onGoToWallet: widget.onFinished),
      ],
    );
  }
}

class _CheckingPage extends StatelessWidget {
  final AppLocalizations l10n;
  final ValueChanged<String?>? onPickOutcome;

  const _CheckingPage({required this.l10n, required this.onPickOutcome});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return _Page(
      background: const OnboardingBackground(),
      content: [
        Text.rich(
          TextSpan(
            style: text.titleHero.copyWith(color: colors.textContent),
            children: [
              for (final (i, part) in l10n.mainnetMigrationTitle.split('*').indexed)
                TextSpan(
                  text: part,
                  style: i.isOdd ? TextStyle(color: colors.accentFlare) : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.mainnetMigrationChecking, style: text.bodyLarge.copyWith(color: colors.textMuted)),
        if (onPickOutcome != null) ...[
          const SizedBox(height: 24),
          Text('DEBUG: pick the testnet outcome', style: text.caption.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final outcome in [...debugTestnetOutcomes, null])
                IntrinsicWidth(
                  child: QuantusButton.simple(
                    label: outcome ?? 'real',
                    onTap: () => onPickOutcome!(outcome),
                    variant: ButtonVariant.staged,
                    width: null,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 52),
        LinearProgressIndicator(
          minHeight: 4,
          backgroundColor: colors.bgSurface2,
          color: colors.semanticGlacier,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.mainnetMigrationReadingHistory.toUpperCase(),
          style: text.labelData.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _OutcomePage extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncValue<TestnetStatus> status;
  final bool creating;
  final void Function(TestnetUserKind? kind) onKeep;
  final void Function({required bool checkFailed}) onCreateNewWallet;

  const _OutcomePage({
    required this.l10n,
    required this.status,
    required this.creating,
    required this.onKeep,
    required this.onCreateNewWallet,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final title = text.titleHero.copyWith(color: colors.textContent);
    final body = text.bodyLarge.copyWith(color: colors.textMuted);
    const symbol = AppConstants.tokenSymbol;

    return status.when(
      loading: () => const ScaffoldBase(mainContent: Center(child: Loader())),
      error: (_, _) => _outcome(
        kind: null,
        content: [
          QuantusBadge(label: l10n.mainnetMigrationUnreachableBadge, tone: BadgeTone.glacier, dot: true),
          const SizedBox(height: 16),
          Text(l10n.mainnetMigrationUnreachableTitle, style: title),
          const SizedBox(height: 16),
          Text(l10n.mainnetMigrationUnreachableBody(symbol), style: body),
          const SizedBox(height: 16),
          Text(l10n.mainnetMigrationUnreachableRewards, style: body),
        ],
      ),
      data: (status) => switch (status.kind) {
        TestnetUserKind.miner => _outcome(
          kind: TestnetUserKind.miner,
          content: [
            Text(
              l10n.mainnetMigrationBlocksMinedCount(status.blocksMined),
              style: text.amountHero.copyWith(color: colors.textContent),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.mainnetMigrationBlocksMined.toUpperCase(),
              style: text.labelData.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 34),
            Text(l10n.mainnetMigrationMinerTitle, style: title),
            const SizedBox(height: 10),
            Text(l10n.mainnetMigrationMinerBody, style: body),
          ],
        ),
        TestnetUserKind.holder || TestnetUserKind.newcomer => _outcome(
          kind: status.kind,
          content: [
            Text(l10n.mainnetMigrationNotMinedTitle, style: title),
            const SizedBox(height: 16),
            Text(l10n.mainnetMigrationNotMinedBody(symbol), style: body),
          ],
        ),
      },
    );
  }

  /// Miners only keep; everyone else may start over, and an unreachable
  /// testnet ([kind] null) gets the more careful confirmation.
  Widget _outcome({required TestnetUserKind? kind, required List<Widget> content}) => _Page(
    content: content,
    actions: [
      QuantusButton.simple(
        key: const Key(E2EKeys.mainnetMigrationKeepWalletButton),
        label: l10n.mainnetMigrationKeepWallet,
        onTap: () => onKeep(kind),
        isDisabled: creating,
      ),
      if (kind != TestnetUserKind.miner) ...[
        const SizedBox(height: 10),
        QuantusButton.simple(
          key: const Key(E2EKeys.mainnetMigrationCreateWalletButton),
          label: l10n.mainnetMigrationCreateWallet,
          onTap: () => onCreateNewWallet(checkFailed: kind == null),
          variant: ButtonVariant.staged,
          isLoading: creating,
        ),
      ],
    ],
  );
}

class _AllSetPage extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onGetTokens;
  final VoidCallback onGoToWallet;

  const _AllSetPage({required this.l10n, required this.onGetTokens, required this.onGoToWallet});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    const symbol = AppConstants.tokenSymbol;

    return _Page(
      background: const OnboardingBackground(),
      content: [
        QuantusBadge(label: l10n.mainnetMigrationAllSetBadge, tone: BadgeTone.sage, dot: true),
        const SizedBox(height: 16),
        Text(l10n.mainnetMigrationAllSetTitle, style: text.titleSuccess.copyWith(color: colors.textContent)),
        const SizedBox(height: 16),
        Text(l10n.mainnetMigrationAllSetBody(symbol), style: text.bodyLarge.copyWith(color: colors.textMuted)),
      ],
      actions: [
        QuantusButton.simple(
          key: const Key(E2EKeys.mainnetMigrationGetTokensButton),
          label: l10n.mainnetMigrationGetTokens(symbol),
          onTap: onGetTokens,
        ),
        const SizedBox(height: 10),
        QuantusButton.simple(
          key: const Key(E2EKeys.mainnetMigrationGoToWalletButton),
          label: l10n.mainnetMigrationGoToWallet,
          onTap: onGoToWallet,
          variant: ButtonVariant.staged,
        ),
      ],
    );
  }
}

/// Logo top left, [content] settled at the bottom (scrolling when tall),
/// [actions] under it.
class _Page extends StatelessWidget {
  final Widget? background;
  final List<Widget> content;
  final List<Widget> actions;

  const _Page({this.background, required this.content, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      backgroundWidget: background,
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          SvgPicture.asset('assets/v2/uppercase_q.svg', width: 30, height: 30),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: content,
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[const SizedBox(height: 40), ...actions],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
