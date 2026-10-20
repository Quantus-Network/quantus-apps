import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorsV3.bgVoid,
      body: const Center(child: Loader(size: 24)),
    );
  }
}
