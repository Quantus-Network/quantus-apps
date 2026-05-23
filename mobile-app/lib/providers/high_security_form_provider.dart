import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class HighSecurityFormNotifier extends StateNotifier<HighSecurityData> {
  HighSecurityFormNotifier() : super(const HighSecurityData());
  void updateGuardianAddress(String address) {
    state = state.copyWith(guardianAddress: address);
  }

  void updateSafeguardWindow(int window) {
    state = state.copyWith(safeguardWindow: Duration(seconds: window));
  }

  void resetState() {
    state = const HighSecurityData();
  }
}

// Provider
final highSecurityFormProvider = StateNotifierProvider<HighSecurityFormNotifier, HighSecurityData>((ref) {
  return HighSecurityFormNotifier();
});
