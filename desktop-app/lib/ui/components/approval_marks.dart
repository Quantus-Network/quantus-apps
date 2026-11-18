import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One mark for each approval a multisig's proposal needs, the first
/// [approved] of them filled. What they count is said in words beside them,
/// so a screen reader passes them over.
class ApprovalMarks extends StatelessWidget {
  const ApprovalMarks({super.key, required this.approved, required this.needed});

  final int approved;
  final int needed;

  static const double _size = 10;
  static const double _gap = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < needed; i++)
            Container(
              width: _size,
              height: _size,
              margin: EdgeInsets.only(left: i == 0 ? 0 : _gap),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < approved ? colors.semanticSage : null,
                border: Border.all(color: i < approved ? colors.semanticSage : colors.borderEmphasis, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
