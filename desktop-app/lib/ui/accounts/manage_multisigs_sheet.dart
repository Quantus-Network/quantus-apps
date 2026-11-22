import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_switch.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/utils/managed_multisigs.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/utils/multisig_local_signers.dart';

/// Adds and removes multisigs: one list of those saved and those the chain
/// reports for this wallet's accounts, with a switch on each row. It cannot
/// be closed while a change is saving.
class ManageMultisigsSheet extends ConsumerStatefulWidget {
  const ManageMultisigsSheet({super.key});

  static Key switchKey(String accountId) => ValueKey('manage-multisig-$accountId');

  @override
  ConsumerState<ManageMultisigsSheet> createState() => _ManageMultisigsSheetState();
}

class _ManageMultisigsSheetState extends ConsumerState<ManageMultisigsSheet> {
  /// In the order first shown, so a row stays where it is when switched.
  List<MultisigAccount> _rows = const [];

  /// The rows first shown as saved, which keep a line for their name while
  /// the sheet is open: a line coming or going would move the switches below
  /// it from under the pointer.
  final _rowsWithNameLine = <String>{};

  final _saving = <String>{};
  final _errors = <String, String>{};

  Future<void> _toggle(MultisigAccount multisig, {required bool on}) async {
    final l10n = ref.read(l10nProvider);
    final manager = ref.read(accountManagerProvider);
    final id = multisig.accountId;
    setState(() {
      _saving.add(id);
      _errors.remove(id);
    });

    String? error;
    try {
      if (on) {
        await manager.addMultisig(multisig);
      } else {
        await manager.removeMultisig(multisig);
      }
    } catch (e) {
      quantusPrint('Switching multisig $id ${on ? 'on' : 'off'} failed: $e');
      error = on ? l10n.multisigAddFailed('$e') : l10n.accountMenuDisconnectError;
    }
    if (!mounted) return;
    setState(() {
      _saving.remove(id);
      if (error != null) _errors[id] = error;
    });
  }

  String _detail(AppLocalizations l10n, MultisigAccount multisig, List<Account> accounts) {
    final approvals = l10n.multisigThresholdOf(multisig.threshold, multisig.signers.length);
    final me =
        accounts.where((a) => a.accountId == multisig.myMemberAccountId).firstOrNull ??
        localSignersForMultisig(multisig, accounts).firstOrNull;
    return me == null ? approvals : l10n.desktopManageMultisigsSignsAs(approvals, me.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final saved = ref.watch(multisigAccountsProvider).value ?? const <MultisigAccount>[];
    final found = ref.watch(discoveredMultisigsProvider);
    final creating = ref.watch(pendingMultisigCreationsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final savedIds = saved.map((multisig) => multisig.accountId).toSet();
    final shownBefore = _rows.map((multisig) => multisig.accountId).toSet();
    _rows = managedMultisigRows(_rows, saved: saved, found: found.value ?? const [], creating: creating);
    _rowsWithNameLine.addAll(
      _rows.map((row) => row.accountId).where((id) => !shownBefore.contains(id) && savedIds.contains(id)),
    );
    final hasFailed = found.hasError && !found.isLoading;

    return PopScope(
      canPop: _saving.isEmpty,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellSheetHeader(title: l10n.desktopManageMultisigsTitle),
          const SizedBox(height: 10),
          Text(l10n.desktopManageMultisigsLead, style: text.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: 16),
          if (found.isLoading) ...[
            TerminalBusyLine(label: l10n.desktopManageMultisigsFinding),
            const SizedBox(height: 12),
          ],
          if (hasFailed) ...[
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.multisigAddDiscoverFailed('${found.error}'),
                      style: text.caption.copyWith(color: colors.semanticEmber),
                    ),
                  ),
                ),
                SheetButton(
                  label: l10n.commonTryAgain,
                  kind: SheetButtonKind.secondary,
                  onTap: () => ref.invalidate(discoveredMultisigsProvider),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_rows.isNotEmpty)
            Flexible(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: context.radiusV3.smBorder,
                  border: Border.all(color: colors.borderHairline),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, multisig) in _rows.indexed)
                        _MultisigRow(
                          key: ValueKey(multisig.accountId),
                          multisig: multisig,
                          isOn: savedIds.contains(multisig.accountId),
                          hasNameLine: _rowsWithNameLine.contains(multisig.accountId),
                          detail: _detail(l10n, multisig, accounts),
                          error: _errors[multisig.accountId],
                          hasDivider: index < _rows.length - 1,
                          onChanged: _saving.contains(multisig.accountId) ? null : (on) => _toggle(multisig, on: on),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else if (found.hasValue && !found.isLoading)
            Text(l10n.multisigAddNoneFound, style: text.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [SheetButton(label: l10n.commonDone, onTap: () => Navigator.of(context).maybePop())],
          ),
        ],
      ),
    );
  }
}

/// A multisig by its name, once it is in the app, its whole address and
/// checkphrase, how it is signed, and its switch.
class _MultisigRow extends StatelessWidget {
  const _MultisigRow({
    super.key,
    required this.multisig,
    required this.isOn,
    required this.hasNameLine,
    required this.detail,
    required this.error,
    required this.hasDivider,
    required this.onChanged,
  });

  final MultisigAccount multisig;
  final bool isOn;

  /// Whether the row holds a line for its name, empty while it is off.
  final bool hasNameLine;
  final String detail;
  final String? error;
  final bool hasDivider;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final error = this.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: hasDivider ? Border(bottom: BorderSide(color: colors.borderHairline)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNameLine) ...[
                  Visibility(
                    visible: isOn,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: AccountLabel(
                      account: multisig,
                      style: text.bodyEmphasis.copyWith(color: colors.textContent),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                DesktopAddressCheckphrase(address: multisig.accountId, isCompact: true),
                const SizedBox(height: 4),
                Text(detail, style: text.caption.copyWith(color: colors.textMuted)),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(error, style: text.caption.copyWith(color: colors.semanticEmber)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          DesktopSwitch(
            key: ManageMultisigsSheet.switchKey(multisig.accountId),
            value: isOn,
            label: isOn ? multisig.name : multisig.accountId,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
