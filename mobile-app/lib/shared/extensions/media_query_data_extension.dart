import 'package:flutter/material.dart';

extension MediaQueryDataExtension on BuildContext {
  bool get isTablet => MediaQuery.of(this).size.width > 600;
  bool get isSmallHeight => MediaQuery.of(this).size.height < 750;

  double get containerHalfWidth => MediaQuery.of(this).size.width * 0.5;
  double getHorizontalCenterPosition(double sphereWidth) => containerHalfWidth - (sphereWidth / 2);

  double get containerHalfHeight => MediaQuery.of(this).size.height * 0.5;
  double getVerticalCenterPosition(double sphereHeight) => containerHalfHeight - (sphereHeight / 2);
}
