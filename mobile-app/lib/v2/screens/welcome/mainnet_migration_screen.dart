import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mainnet_migration_provider.dart';
import 'package:resonance_network_wallet/services/mainnet_migration_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/info_card.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/settings/reset_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/onboarding_background.dart';

/// Shown once to wallets that predate mainnet: a branded intro while the
/// testnet check runs, then a page written for what this wallet did there.
class MainnetMigrationScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinished;

  const MainnetMigrationScreen({super.key, required this.onFinished});

  @override
  ConsumerState<MainnetMigrationScreen> createState() => _MainnetMigrationScreenState();
}

class _MainnetMigrationScreenState extends ConsumerState<MainnetMigrationScreen> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.animateToPage(1, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);

  void _finish(TestnetUserKind? kind) {
    ref.read(mainnetMigrationServiceProvider).markDone();
    TelemetryService().sendEvent('mainnet_migration_done', parameters: {'testnet_user': kind?.name ?? 'unknown'});
    widget.onFinished();
  }

  void _createNewWallet() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetConfirmationScreen()));

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    // Watched here so the check runs while the intro page is still showing.
    final status = ref.watch(testnetStatusProvider);
    final forced = ref.watch(forcedTestnetOutcomeProvider);

    return PageView(
      key: const Key(E2EKeys.mainnetMigrationScreen),
      controller: _pages,
      children: [
        _IntroPage(
          l10n: l10n,
          onNext: _next,
          debugOutcome: forced,
          onDebugOutcome: (outcome) => ref.read(forcedTestnetOutcomeProvider.notifier).state = outcome,
        ),
        _StatusPage(
          l10n: l10n,
          status: status,
          onFinish: _finish,
          onCreateNewWallet: _createNewWallet,
          onRetry: () => ref.invalidate(testnetStatusProvider),
        ),
      ],
    );
  }
}

class _IntroPage extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onNext;
  final String? debugOutcome;
  final ValueChanged<String> onDebugOutcome;

  const _IntroPage({
    required this.l10n,
    required this.onNext,
    required this.debugOutcome,
    required this.onDebugOutcome,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      backgroundWidget: const OnboardingBackground(),
      mainContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Image.asset('assets/v2/quantus_orange_logo.png', height: 32),
          const SizedBox(height: 16),
          Text(
            l10n.mainnetMigrationTitle,
            textAlign: TextAlign.center,
            style: text.titleHero.copyWith(color: colors.textWhite),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.mainnetMigrationIntro,
            textAlign: TextAlign.center,
            style: text.body.copyWith(color: colors.textContent),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.mainnetMigrationChecking,
            textAlign: TextAlign.center,
            style: text.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 56),
          if (debugOutcome != null) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final outcome in debugTestnetOutcomes)
                  ChoiceChip(
                    label: Text(outcome),
                    selected: outcome == debugOutcome,
                    onSelected: (_) => onDebugOutcome(outcome),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          QuantusButton.simple(
            key: const Key(E2EKeys.mainnetMigrationNextButton),
            label: l10n.mainnetMigrationNext,
            onTap: onNext,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _StatusPage extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncValue<TestnetStatus> status;
  final void Function(TestnetUserKind? kind) onFinish;
  final VoidCallback onCreateNewWallet;
  final VoidCallback onRetry;

  const _StatusPage({
    required this.l10n,
    required this.status,
    required this.onFinish,
    required this.onCreateNewWallet,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return status.when(
      loading: () => const ScaffoldBase(mainContent: Center(child: Loader())),
      // Testnet unreachable: the holder page covers both outcomes in its copy.
      error: (_, _) => _holder(checkFailed: true),
      data: (status) => switch (status.kind) {
        TestnetUserKind.miner => _Outcome(
          l10n: l10n,
          title: l10n.mainnetMigrationMinerTitle,
          paragraphs: [l10n.mainnetMigrationMinerThanks, l10n.mainnetMigrationMinerKeep],
          blocksMined: status.blocksMined,
          trailingParagraphs: [l10n.mainnetMigrationMinerBalance(AppConstants.tokenSymbol)],
          actions: [_finishButton(l10n.commonDone, TestnetUserKind.miner)],
        ),
        TestnetUserKind.holder => _holder(),
        TestnetUserKind.newcomer => _Outcome(
          l10n: l10n,
          title: l10n.mainnetMigrationUserTitle,
          paragraphs: [l10n.mainnetMigrationNewcomerBody, l10n.mainnetMigrationNewcomerZero(AppConstants.tokenSymbol)],
          actions: [
            _createWalletButton(primary: true),
            const SizedBox(height: 16),
            _finishButton(l10n.mainnetMigrationMigrateWallet, TestnetUserKind.newcomer, primary: false),
          ],
        ),
      },
    );
  }

  Widget _holder({bool checkFailed = false}) => _Outcome(
    l10n: l10n,
    title: l10n.mainnetMigrationUserTitle,
    paragraphs: [l10n.mainnetMigrationHolderIntro],
    cards: [
      InfoCard(
        leading: const AccountBadge.icon(icon: Icons.memory_rounded),
        title: l10n.mainnetMigrationHolderMinedTitle,
        description: l10n.mainnetMigrationHolderMinedBody,
      ),
      InfoCard(
        leading: const AccountBadge.icon(icon: Icons.key_rounded),
        title: l10n.mainnetMigrationHolderNotMinedTitle,
        description: l10n.mainnetMigrationHolderNotMinedBody,
      ),
    ],
    warning: checkFailed
        ? InfoCard(
            leading: const AccountBadge.icon(icon: Icons.warning_amber_rounded, isActive: true),
            title: l10n.mainnetMigrationUnreachableTitle,
            description: l10n.mainnetMigrationUnreachableBody,
            trailing: QuantusButton.simple(
              key: const Key(E2EKeys.mainnetMigrationRetryButton),
              label: l10n.commonRetry,
              onTap: onRetry,
              variant: ButtonVariant.underline,
              width: null,
              padding: EdgeInsets.zero,
            ),
          )
        : null,
    actions: [
      _finishButton(l10n.mainnetMigrationKeepWallet, checkFailed ? null : TestnetUserKind.holder),
      const SizedBox(height: 16),
      _createWalletButton(primary: false),
    ],
  );

  Widget _finishButton(String label, TestnetUserKind? kind, {bool primary = true}) => QuantusButton.simple(
    key: const Key(E2EKeys.mainnetMigrationFinishButton),
    label: label,
    onTap: () => onFinish(kind),
    variant: primary ? ButtonVariant.primary : ButtonVariant.staged,
  );

  Widget _createWalletButton({required bool primary}) => QuantusButton.simple(
    key: const Key(E2EKeys.mainnetMigrationCreateWalletButton),
    label: l10n.welcomeCreateNewWallet,
    onTap: onCreateNewWallet,
    variant: primary ? ButtonVariant.primary : ButtonVariant.staged,
  );
}

class _Outcome extends StatelessWidget {
  final AppLocalizations l10n;
  final String title;
  final List<String> paragraphs;
  final int? blocksMined;
  final List<String> trailingParagraphs;
  final List<Widget> cards;
  final Widget? warning;
  final List<Widget> actions;

  const _Outcome({
    required this.l10n,
    required this.title,
    required this.paragraphs,
    this.blocksMined,
    this.trailingParagraphs = const [],
    this.cards = const [],
    this.warning,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final body = text.body.copyWith(color: colors.textContent);

    return ScaffoldBase(
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Image.asset('assets/v2/quantus_orange_logo.png', height: 32, alignment: Alignment.centerLeft),
            const SizedBox(height: 32),
            Text(title, style: text.titleScreen.copyWith(color: colors.textWhite)),
            if (warning != null) ...[const SizedBox(height: 16), warning!],
            for (final paragraph in paragraphs) ...[const SizedBox(height: 16), Text(paragraph, style: body)],
            if (blocksMined != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.mainnetMigrationBlocksMinedCount(blocksMined!),
                      style: text.amountHero.copyWith(color: colors.accentFlare),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.mainnetMigrationBlocksMined, style: text.caption.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
            ],
            for (final paragraph in trailingParagraphs) ...[const SizedBox(height: 16), Text(paragraph, style: body)],
            for (final (i, card) in cards.indexed) ...[SizedBox(height: i == 0 ? 24 : 14), card],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}
