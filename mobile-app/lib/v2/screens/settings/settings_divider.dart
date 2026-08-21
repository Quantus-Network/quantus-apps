import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

enum SettingsDividerStyle { list, walletSection, sectionEmphasis, cardInterior, currencyList }

class SettingsDivider extends StatelessWidget {
  final SettingsDividerStyle style;
  final EdgeInsets padding;

  const SettingsDivider({
    super.key,
    this.style = SettingsDividerStyle.list,
    this.padding = const EdgeInsets.only(top: 16, bottom: 24),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget divider;

    switch (style) {
      case SettingsDividerStyle.list:
      case SettingsDividerStyle.walletSection:
        divider = Divider(color: colors.toasterBackground, thickness: 1);
      case SettingsDividerStyle.sectionEmphasis:
        divider = Divider(color: colors.surfaceDeep, thickness: 1);
      case SettingsDividerStyle.cardInterior:
        divider = Divider(color: colors.separator, thickness: 1);
      case SettingsDividerStyle.currencyList:
        divider = Divider(color: colors.background, thickness: 2);
    }

    return Padding(padding: padding, child: divider);
  }
}
