import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class HighSecurityFormNotifier extends StateNotifier<HighSecurityData> {
  HighSecurityFormNotifier() : super(const HighSecurityData());
  void updateGuardianAddress(String address) {
    state = state.copyWith(guardianAddress: address);
  }

  void updateSafeguardWindow(int window) {
    state = state.copyWith(safeguardWindow: window);
  }

  void resetState() {
    state = const HighSecurityData();
  }
}

// Provider
final highSecurityFormProvider = StateNotifierProvider<HighSecurityFormNotifier, HighSecurityData>((ref) {
  return HighSecurityFormNotifier();
});
