import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Thin hairline divider used between rows in account/menu lists.
class MenuDivider extends StatelessWidget {
  const MenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(color: context.colors.toasterBackground, height: 1);
}
