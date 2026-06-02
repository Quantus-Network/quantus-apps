import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/loader.dart';
import 'package:quantus_cold_wallet/components/mnemonic_grid.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/screens/set_password_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  List<String>? _words;

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
    Navigator.push(context, MaterialPageRoute(builder: (_) => SetPasswordScreen(mnemonic: words.join(' '))));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final words = _words;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Recovery phrase'),
      mainContent: words == null
          ? const Center(child: Loader(size: 24))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Write these words down in order and keep them offline. Anyone with this phrase controls your funds. '
                  'It is never shown again and cannot be copied from this device.',
                  style: text.smallParagraph?.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(child: MnemonicGrid(words: words, isRevealed: true)),
                ),
              ],
            ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: "I've written it down", onTap: words == null ? null : _continue),
      ),
    );
  }
}
