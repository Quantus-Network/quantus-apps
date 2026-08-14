import 'package:flutter/material.dart';

class SuccessCheck extends StatelessWidget {
  final double size;
  const SuccessCheck({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/v2/green_checkmark.png', width: size, height: size);
  }
}
