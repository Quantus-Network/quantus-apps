class HighSecurityData {
  final String guardianAccountId;
  final Duration safeguardWindow;

  const HighSecurityData({
    this.guardianAccountId = '',
    this.safeguardWindow = const Duration(hours: 10), // 10 hours in seconds
  });

  HighSecurityData copyWith({String? guardianAddress, Duration? safeguardWindow}) {
    return HighSecurityData(
      guardianAccountId: guardianAddress ?? guardianAccountId,
      safeguardWindow: safeguardWindow ?? this.safeguardWindow,
    );
  }
}
