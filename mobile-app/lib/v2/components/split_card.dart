import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SplitCard extends StatelessWidget {
  final Widget topChild;
  final Widget bottomChild;

  const SplitCard({super.key, required this.topChild, required this.bottomChild});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final topPadding = const EdgeInsets.only(top: 32, bottom: 24, left: 24, right: 24);
    final bottomPadding = const EdgeInsets.only(top: 24, bottom: 32, left: 24, right: 24);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: topPadding, child: topChild),
              Divider(color: colors.bgVoid, thickness: 4),
              Container(padding: bottomPadding, child: bottomChild),
            ],
          ),
        ),
      ],
    );
  }
}
