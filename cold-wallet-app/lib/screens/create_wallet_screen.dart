import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/advanced_section.dart';
import 'package:quantus_cold_wallet/components/scheme_picker.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/screens/unlock_method_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// The mandatory recovery-phrase step of Create New Key. The only way forward
/// is "I've written it down", which is the only place the unlock-method step
/// is reached from on the create path.
class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  List<String>? _words;
  DilithiumScheme _scheme = ColdAccount.newAccountScheme;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final mnemonic = await SubstrateService().generateMnemonic();
    if (!mounted) return;
    setState(() => _words = mnemonic.split(' '));
  }

  void _continue() {
    final words = _words;
    if (words == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnlockMethodScreen(
          mnemonic: words.join(' '),
          accounts: [ColdAccount(label: 'Main key', index: 0, scheme: _scheme)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final words = _words;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'New Key'),
      mainContent: words == null
          ? const Center(child: Loader(size: 24))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Save your recovery phrase', style: text.titleScreen.copyWith(color: colors.textContent)),
                const SizedBox(height: 8),
                Text(
                  'Write these words down in order and keep them offline. Anyone with this phrase controls your funds. '
                  'It is never shown again and cannot be copied from this device.',
                  style: text.body.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.bgSurface,
                            borderRadius: context.radiusV3.mdBorder,
                            border: Border.all(color: colors.borderHairline),
                          ),
                          child: MnemonicGrid(words: words, isRevealed: true),
                        ),
                        const SizedBox(height: 24),
                        AdvancedSection(
                          children: [
                            SchemePicker(value: _scheme, onChanged: (scheme) => setState(() => _scheme = scheme)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: "I've written it down",
          padding: coldButtonPadding,
          onTap: words == null ? null : _continue,
        ),
      ),
    );
  }
}
