import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class ReversibleTimer extends StatelessWidget {
  final Duration remainingTime;

  const ReversibleTimer({super.key, required this.remainingTime});

  String getFirstTimeCol(FormattedDuration time) {
    if (time.days != null) {
      return '${time.days!}d';
    } else {
      return '${time.hours}h';
    }
  }

  String getSecondTimeCol(FormattedDuration time) {
    if (time.days != null) {
      return '${time.hours}h';
    } else {
      return '${time.minutes}m';
    }
  }

  String getThirdTimeCol(FormattedDuration time) {
    if (time.days != null) {
      return '${time.minutes}m';
    } else {
      return '${time.seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DatetimeFormattingService.formatDuration(remainingTime);

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 18,
        children: [
          Text(getFirstTimeCol(time), textAlign: TextAlign.center, style: context.themeText.timer),
          Text(':', textAlign: TextAlign.center, style: context.themeText.timer),
          Text(getSecondTimeCol(time), textAlign: TextAlign.center, style: context.themeText.timer),
          Text(':', textAlign: TextAlign.center, style: context.themeText.timer),
          Text(getThirdTimeCol(time), textAlign: TextAlign.center, style: context.themeText.timer),
        ],
      ),
    );
  }
}
