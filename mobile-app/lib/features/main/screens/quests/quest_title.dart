import 'package:flutter/material.dart';

class QuestTitle extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const QuestTitle({super.key, this.padding = const EdgeInsetsGeometry.only(top: 24)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 11,
        children: [
          Image.asset('assets/navbar/qcat_navbar_icon.png', width: 82),
          Image.asset('assets/qq-logo.png', width: 226.35),
        ],
      ),
    );
  }
}
