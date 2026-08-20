import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TxItemSkeleton extends StatelessWidget {
  const TxItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const double txItemHeight = 32.0;
    const double txItemDetailHeight = 12.0;

    return const Row(
      children: [
        Skeleton(width: txItemHeight, height: txItemHeight),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 64, height: txItemDetailHeight),
            SizedBox(height: 6),
            Skeleton(width: 52, height: txItemDetailHeight),
          ],
        ),
        Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Skeleton(width: 100, height: txItemDetailHeight),
            SizedBox(height: 6),
            Skeleton(width: 88, height: txItemDetailHeight),
          ],
        ),
      ],
    );
  }
}
