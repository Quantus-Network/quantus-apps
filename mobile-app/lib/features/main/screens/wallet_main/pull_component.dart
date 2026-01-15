import 'package:flutter/material.dart';

class PullComponent extends StatelessWidget {
  const PullComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 320,
          height: 52,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: ShapeDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0xFF0AD4F6)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 17,
            children: [
              SizedBox(width: 30, height: 30, child: Stack()),
              SizedBox(
                width: 192,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'IN CASE OF EMERGENCY\n',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.40,
                        ),
                      ),
                      TextSpan(
                        text: 'PULL ALL FUNDS FROM THIS ACCOUNT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w300,
                          height: 1.40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
