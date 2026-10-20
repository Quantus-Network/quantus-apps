import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = ref.watch(currentAccountProvider);
    if (account == null) return DesktopPage(title: l10n.receiveTitle, child: const Skeleton(height: 200));
    final checkphrase = ref.watch(checksumNameProvider(account.accountId)).value;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.receiveYourAddress, style: text.labelMonogram.copyWith(color: colors.textMuted)),
        const SizedBox(height: 8),
        SelectableText(account.accountId, style: text.dataAddressLarge.copyWith(color: colors.textContent)),
        if (checkphrase != null && checkphrase.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(checkphrase, style: text.body.copyWith(color: colors.semanticLilac)),
        ],
        const SizedBox(height: 20),
        QuantusButton.simple(
          label: l10n.receiveCopy,
          width: 200,
          icon: const Icon(Icons.copy_rounded, size: 16),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: account.accountId));
            if (context.mounted) await context.showCopyToaster(message: l10n.commonCopied);
          },
        ),
        const SizedBox(height: 20),
        QuantusBanner(tone: BannerTone.glacier, message: l10n.receiveCompareBanner),
      ],
    );

    return DesktopPage(
      title: l10n.receiveTitle,
      child: DesktopCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final qr = QuantusQr(accountId: account.accountId, size: 320);
            if (constraints.maxWidth < 760) {
              return Column(children: [qr, const SizedBox(height: 24), details]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                qr,
                const SizedBox(width: 32),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}
