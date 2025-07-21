import 'package:flutter/services.dart';

class DecimalInputFormatter extends TextInputFormatter {
  final RegExp decimalRegex = RegExp(r'^(0|([1-9]\d*))([,.]\d*)?$|^$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty input
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Check if the new value matches our regex
    if (decimalRegex.hasMatch(newValue.text)) {
      return newValue;
    } else {
      // Return the old value if new input doesn't match
      return oldValue;
    }
  }
}
