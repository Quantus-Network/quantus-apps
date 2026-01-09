import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

abstract class WalletAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletAppBar._({super.key});
  factory WalletAppBar({Key? key, required String title, VoidCallback? onBack, List<Widget>? actions}) =>
      _StandardWalletAppBar(key: key, title: title, onBack: onBack, actions: actions);

  factory WalletAppBar.simple({Key? key, required String title}) => _SimpleWalletAppBar(key: key, title: title);

  factory WalletAppBar.simpleWithBackButton({Key? key, required String title, VoidCallback? onBack}) =>
      _StandardWalletAppBar(key: key, title: title, onBack: onBack);

  factory WalletAppBar.custom({Key? key, required Widget titleWidget, Widget? leadingWidget, List<Widget>? actions}) =>
      _CustomWalletAppBar(key: key, titleWidget: titleWidget, leadingWidget: leadingWidget, actions: actions);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SimpleWalletAppBar extends WalletAppBar {
  final String title;
  const _SimpleWalletAppBar({super.key, required this.title}) : super._();
  @override
  Widget build(BuildContext context) {
    return _baseAppBar(
      context,
      title: Text(title, style: context.themeText.smallTitle),
      leading: const SizedBox(),
      leadingWidth: 9,
    );
  }
}

class _CustomWalletAppBar extends WalletAppBar {
  final Widget titleWidget;
  final Widget? leadingWidget;
  final List<Widget>? actions;
  const _CustomWalletAppBar({super.key, required this.titleWidget, this.leadingWidget, this.actions}) : super._();
  @override
  Widget build(BuildContext context) {
    const topPadding = 24.0;
    return _baseAppBar(
      context,
      title: Padding(
        padding: const EdgeInsets.only(top: topPadding),
        child: titleWidget,
      ),
      leading: leadingWidget ?? const SizedBox(),
      leadingWidth: 9,
      actionsPadding: const EdgeInsets.only(right: 24),
      actions: (actions ?? const [])
          .map(
            (w) => Padding(
              padding: const EdgeInsets.only(top: topPadding),
              child: w,
            ),
          )
          .toList(),
    );
  }
}

class _StandardWalletAppBar extends WalletAppBar {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  const _StandardWalletAppBar({super.key, required this.title, this.onBack, this.actions}) : super._();
  @override
  Widget build(BuildContext context) {
    final canBePop = Navigator.canPop(context) || onBack != null;
    final handleBack = onBack ?? () => Navigator.of(context).pop();
    return _baseAppBar(
      context,
      titleSpacing: -16,
      leading: canBePop
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios, size: context.themeSize.appbarIconSize),
              onPressed: handleBack,
            )
          : null,
      title: GestureDetector(
        onTap: canBePop ? handleBack : null,
        child: Text(title, style: context.themeText.detail),
      ),
      actions: actions,
    );
  }
}

AppBar _baseAppBar(
  BuildContext context, {
  Widget? title,
  Widget? leading,
  List<Widget>? actions,
  EdgeInsetsGeometry? actionsPadding,
  double? leadingWidth,
  double? titleSpacing,
}) {
  return AppBar(
    iconTheme: IconThemeData(color: context.themeColors.light),
    centerTitle: false,
    automaticallyImplyLeading: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: leading,
    leadingWidth: leadingWidth,
    title: title,
    titleSpacing: titleSpacing,
    actionsPadding: actionsPadding,
    actions: actions,
  );
}
