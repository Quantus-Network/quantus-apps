import 'package:quantus_sdk/quantus_sdk.dart';

class HighSecurityData {
  final String guardianAccountId;
  final Duration safeguardWindow;

  const HighSecurityData({
    this.guardianAccountId = '',
    this.safeguardWindow = const Duration(hours: 10), // 10 hours in seconds
  });

  HighSecurityData copyWith({Account? account, String? guardianAddress, Duration? safeguardWindow}) {
    return HighSecurityData(
      guardianAccountId: guardianAddress ?? guardianAccountId,
      safeguardWindow: safeguardWindow ?? this.safeguardWindow,
    );
  }
}
