import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/accounts/delete_wallet_step.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The Disconnect Wallet sheet: deletes a whole software wallet from this
/// app, every account in it and its recovery phrase, as [DeleteWalletStep]
/// has it. It is about the wallet it was opened for
/// ([disconnectWalletTargetProvider]), and closes if that wallet goes.
class DisconnectWalletSheet extends ConsumerStatefulWidget {
  const DisconnectWalletSheet({super.key});

  static const backedUpKey = Key('disconnect-wallet-backed-up');
  static const cancelKey = Key('disconnect-wallet-cancel');
  static const deleteKey = Key('disconnect-wallet-delete');

  @override
  ConsumerState<DisconnectWalletSheet> createState() => _DisconnectWalletSheetState();
}

class _DisconnectWalletSheetState extends ConsumerState<DisconnectWalletSheet> {
  /// Read once: the sheet stays on the wallet it opened for.
  late final int _walletIndex =
      ref.read(disconnectWalletTargetProvider) ??
      (throw StateError('The Disconnect Wallet sheet opened without a wallet'));

  /// What the sheet last showed. While the accounts are read again after a
  /// change they are not known, and the sheet keeps to these meanwhile.
  String? _wallet;
  int _accountCount = 0;

  bool _isClosing = false;

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    Navigator.of(context).maybePop();
  }

  /// The wallet is gone (disconnected elsewhere): the sheet goes with it,
  /// once the frame that found out is done.
  void _closeAfterFrame() {
    if (_isClosing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final accounts = ref.watch(accountsProvider).value;
    if (accounts != null) {
      final count = accounts.where((a) => a.walletIndex == _walletIndex).length;
      if (count == 0) {
        _closeAfterFrame();
      } else {
        _accountCount = count;
        _wallet = ref.watch(walletLabelProvider(_walletIndex)) ?? _wallet;
      }
    }
    final wallet = _wallet;
    if (wallet == null) return const SizedBox.shrink();

    return DeleteWalletStep(
      wallet: wallet,
      firstLine: l10n.desktopDisconnectWalletAccounts(wallet, _accountCount),
      delete: () => ref.read(accountManagerProvider).disconnectWallet(_walletIndex),
      onCancel: _close,
      onDeleted: _close,
      l10n: l10n,
      backedUpKey: DisconnectWalletSheet.backedUpKey,
      cancelKey: DisconnectWalletSheet.cancelKey,
      deleteKey: DisconnectWalletSheet.deleteKey,
    );
  }
}
