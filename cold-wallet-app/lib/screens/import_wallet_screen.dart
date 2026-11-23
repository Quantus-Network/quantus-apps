import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/derivation_field.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/unlock_method_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Import Key: a recovery phrase and the account it should derive. Never
/// shows the phrase back; a valid phrase goes straight to the unlock method.
class ImportWalletScreen extends ConsumerStatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  ConsumerState<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends ConsumerState<ImportWalletScreen> {
  final _controller = ObscuringTextEditingController();
  final _buttonKey = GlobalKey();
  bool _isLoading = false;
  String? _phraseError;
  String? _derivationError;
  ColdAccount? _account = ColdAccount(label: 'Main key', index: 0, scheme: ColdAccount.newAccountScheme);

  bool get _hasInput => _controller.text.trim().isNotEmpty;

  Future<void> _import() async {
    final mnemonic = _controller.text.trim();

    if (!mnemonic.startsWith('//')) {
      final words = mnemonic.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.length != 12 && words.length != 24) {
        setState(() => _phraseError = 'Recovery phrase must be 12 or 24 words');
        return;
      }
    }

    final account = _account;
    if (account == null) {
      setState(() => _derivationError = 'Enter a valid account index or derivation path');
      return;
    }

    setState(() {
      _isLoading = true;
      _phraseError = null;
      _derivationError = null;
    });

    try {
      // The scheme is chosen in the derivation field (ADVANCED), so import the
      // one account it names. Throws on an invalid phrase.
      ref.read(hdWalletServiceProvider).keyPairAtPath(mnemonic, account.derivationPath, account.scheme);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UnlockMethodScreen(mnemonic: mnemonic, accounts: [account.withLabel('Main key')]),
        ),
      );
    } catch (e) {
      debugPrint('Import rejected: $e');
      if (mounted) setState(() => _phraseError = 'Not a valid recovery phrase');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Import Key'),
      mainContent: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Restore an existing key with its 12 or 24 word recovery phrase.',
                style: text.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 16),
              QuantusSeedPhraseField(
                controller: _controller,
                hint: 'Type in or paste your recovery phrase. Separate words with spaces.',
                error: _phraseError,
                onChanged: (_) => setState(() => _phraseError = null),
                scrollToOnFocus: _buttonKey,
              ),
              const SizedBox(height: 20),
              DerivationField(
                onChanged: (a) => setState(() {
                  _account = a;
                  _derivationError = null;
                }),
              ),
              if (_derivationError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _derivationError!,
                  style: text.caption.copyWith(color: colors.semanticEmber),
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
          label: 'Import Key',
          padding: coldButtonPadding,
          onTap: _import,
          isLoading: _isLoading,
          isDisabled: !_hasInput,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
