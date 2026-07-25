import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

/// Thin hairline divider used between rows in account/menu lists.
class MenuDivider extends StatelessWidget {
  const MenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(color: context.colors.toasterBackground, height: 1);
}
