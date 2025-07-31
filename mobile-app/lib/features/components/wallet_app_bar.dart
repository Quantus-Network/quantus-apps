import 'package:flutter/material.dart';

class WalletAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const WalletAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      iconTheme: const IconThemeData(color: Color(0xFFE6E6E6)),
      centerTitle: false,
      titleSpacing: 0,
      leading: (Navigator.canPop(context) || onBack != null)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFE6E6E6),
          fontSize: 12,
          fontFamily: 'Fira Code',
          fontWeight: FontWeight.w400,
        ),
      ),
      actions: actions,
      backgroundColor: const Color(0xFF0E0E0E),
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
