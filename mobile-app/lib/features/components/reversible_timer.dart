import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class ReversibleTimer extends StatelessWidget {
  final Duration? remainingTime;

  const ReversibleTimer({super.key, required this.remainingTime});

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
          Text(
            time.hours,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.44,
            ),
          ),
          const Text(
            ':',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.44,
            ),
          ),
          Text(
            time.minutes,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.44,
            ),
          ),
          const Text(
            ':',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.44,
            ),
          ),
          Text(
            time.seconds,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.44,
            ),
          ),
        ],
      ),
    );
  }
}
