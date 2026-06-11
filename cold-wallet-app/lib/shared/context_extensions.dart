import 'package:flutter/material.dart';

extension MediaQueryDataExtension on BuildContext {
  bool get isTablet => MediaQuery.of(this).size.width > 600;
  bool get isSmallHeight => MediaQuery.of(this).size.height < 750;
}
