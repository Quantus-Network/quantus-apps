class HighSecurityData {
  final String guardianAccountId;
  final int safeguardWindowSeconds;

  const HighSecurityData({
    this.guardianAccountId = '',
    this.safeguardWindowSeconds = 10 * 60 * 60, // 10 hours in seconds
  });

  HighSecurityData copyWith({String? guardianAddress, int? safeguardWindow}) {
    return HighSecurityData(
      guardianAccountId: guardianAddress ?? guardianAccountId,
      safeguardWindowSeconds: safeguardWindow ?? safeguardWindowSeconds,
    );
  }
}
