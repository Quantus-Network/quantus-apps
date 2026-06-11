import 'package:quantus_sdk/src/constants/app_constants.dart';

void printTiming(String label, int milliseconds) {
  if (AppConstants.debugQueryTiming) {
    print('[TIMING] $label: $milliseconds ms');
  }
}
