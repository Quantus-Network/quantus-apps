import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/utils/print.dart';

void printTiming(String label, int milliseconds) {
  if (AppConstants.debugQueryTiming) {
    quantusDebugPrint('[TIMING] $label: $milliseconds ms');
  }
}
