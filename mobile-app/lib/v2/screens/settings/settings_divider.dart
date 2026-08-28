import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsDivider extends StatelessWidget {
  final EdgeInsets padding;

  const SettingsDivider({super.key, this.padding = const EdgeInsets.only(top: 16, bottom: 24)});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: const MenuDivider());
  }
}
