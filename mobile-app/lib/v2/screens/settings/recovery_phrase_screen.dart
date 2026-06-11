import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/recovery_phrase_body.dart';

class RecoveryPhraseScreen extends ConsumerStatefulWidget {
  const RecoveryPhraseScreen({super.key, this.walletIndex = 0});

  final int walletIndex;

  @override
  ConsumerState<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
}

class _RecoveryPhraseScreenState extends ConsumerState<RecoveryPhraseScreen> {
  final _settingsService = SettingsService();
  List<String> _words = [];

  void _loadMnemonic() async {
    final mnemonic = await _settingsService.getMnemonic(widget.walletIndex);
    if (mnemonic != null && mounted) {
      setState(() {
        _words = mnemonic.split(' ');
      });
    }
  }

  void _onPhraseExposed() {
    _settingsService.setRecoveryPhraseViewed(widget.walletIndex);
    ref.invalidate(recoveryPhraseViewedProvider(widget.walletIndex));
  }

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return RecoveryPhraseBody(
      appBarTitle: l10n.settingsRecoveryPhraseTitle,
      words: _words,
      primaryButtonLabel: l10n.settingsRecoveryPhraseDone,
      onPrimary: () => Navigator.of(context).pop(),
      onPhraseExposed: _onPhraseExposed,
    );
  }
}
