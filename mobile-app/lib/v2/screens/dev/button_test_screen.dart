import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart' as gk;
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ButtonTestScreen extends StatelessWidget {
  const ButtonTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Button Test', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
              const SizedBox(height: 32),

              _label('Our GlassButton (outline)', colors, text),
              GlassButton(
                height: 56,
                onTap: () {},
                child: Center(
                  child: Text(
                    'Outline (Clear Outline)',
                    style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Our GlassButton (filled - Clear Glass)', colors, text),
              GlassButton(
                height: 56,
                filled: true,
                onTap: () {},
                child: Center(
                  child: Text(
                    'Filled (Clear Glass)',
                    style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Our GlassButton (disabled 20%)', colors, text),
              Opacity(
                opacity: 0.2,
                child: GlassButton(
                  height: 56,
                  child: Center(
                    child: Text(
                      'Disabled',
                      style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // _label('glass_kit frostedGlass', colors, text),
              // gk.GlassContainer.frostedGlass(
              //   height: 56,
              //   borderRadius: BorderRadius.circular(14),
              //   gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]),
              //   borderGradient: const LinearGradient(
              //     begin: Alignment.topCenter,
              //     end: Alignment.bottomCenter,
              //     colors: [Color(0x55FFFFFF), Color(0x18FFFFFF)],
              //   ),
              //   blur: 20,
              //   frostedOpacity: 0.1,
              //   child: Center(child: Text('Frosted Glass', style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500))),
              // ),
              // const SizedBox(height: 16),

              // _label('glass_kit clearGlass (no fill)', colors, text),
              // gk.GlassContainer.clearGlass(
              //   height: 56,
              //   borderRadius: BorderRadius.circular(14),
              //   gradient: const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
              //   borderGradient: const LinearGradient(
              //     begin: Alignment.topCenter,
              //     end: Alignment.bottomCenter,
              //     colors: [Color(0x70FFFFFF), Color(0x18FFFFFF)],
              //   ),
              //   borderWidth: 0.889,
              //   blur: 20,
              //   child: Center(child: Text('Clear Outline Only', style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500))),
              // ),
              // const SizedBox(height: 32),
              _label('Plain', colors, text),
              gk.GlassContainer.clearGlass(
                height: 56,
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
                // there is no gradient fill in our design.
                // gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)]),
                borderGradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.66),
                    const Color(0xFFFFFFFF).withValues(alpha: 0.66),
                  ],
                ),
                borderWidth: 0.889,
                blur: 20,
                child: Center(
                  child: Text(
                    'Plain',
                    style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('+ inner shadow (top+bottom)', colors, text),
              gk.GlassContainer.clearGlass(
                height: 56,
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
                borderGradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.66),
                    const Color(0xFFFFFFFF).withValues(alpha: 0.66),
                  ],
                ),
                borderWidth: 0.889,
                blur: 20,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.15),
                            ],
                            stops: const [0.0, 0.25, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Top+Bottom',
                        style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _label('Our GlassButton (filled - Clear Glass)', colors, text),
              GlassButton(
                height: 56,
                filled: true,
                onTap: () {},
                child: Center(
                  child: Text(
                    'Current',
                    style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('TARGET: PNG wide', colors, text),
              GlassContainer(
                asset: GlassContainer.wideAsset,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Center(
                  child: Text(
                    'Wide PNG',
                    style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('PNG: glass_button_40_bg (small)', colors, text),
              const Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: GlassContainer(
                      asset: GlassContainer.smallAsset,
                      child: Center(child: Icon(Icons.edit, size: 18, color: Colors.white)),
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: GlassContainer(
                      asset: GlassContainer.smallAsset,
                      child: Center(child: Icon(Icons.copy, size: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // _label('PNG: glass_border_bg', colors, text),
              // SizedBox(
              //   height: 56,
              //   child: GlassContainer(
              //     asset: 'assets/v2/glass_border_bg.png',
              //     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              //     child: Center(child: Text('Border PNG', style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500))),
              //   ),
              // ),
              // const SizedBox(height: 32),
              _label('Action card PNGs', colors, text),
              Row(
                children: [
                  Expanded(child: Image.asset('assets/v2/receive_button.png')),
                  const SizedBox(width: 15),
                  Expanded(child: Image.asset('assets/v2/send_button.png')),
                  const SizedBox(width: 15),
                  Expanded(child: Image.asset('assets/v2/swap_button.png')),
                ],
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String s, AppColorsV2 colors, AppTextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(s, style: text.detail?.copyWith(color: colors.textSecondary)),
    );
  }
}
