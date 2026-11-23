import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_switch.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The row of Settings that says whether the app keeps running when its
/// window closes.
class KeepRunningRow extends ConsumerWidget {
  const KeepRunningRow({super.key});

  static const switchKey = Key('settings-keep-running-switch');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final title = l10n.desktopKeepRunningTitle;

    return SettingsRow.control(
      title: title,
      subtitle: l10n.desktopKeepRunningSubtitle,
      trailing: DesktopSwitch(
        key: switchKey,
        value: ref.watch(keepRunningProvider),
        label: title,
        onChanged: (enabled) => unawaited(ref.read(keepRunningProvider.notifier).setEnabled(enabled)),
      ),
    );
  }
}
