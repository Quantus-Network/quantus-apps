class HighSecurityData {
  final String guardianAddress;
  final int safeguardWindow;

  const HighSecurityData({
    this.guardianAddress = '',
    this.safeguardWindow = 10 * 60 * 60, // 10 hours in seconds
  });

  HighSecurityData copyWith({String? guardianAddress, int? safeguardWindow}) {
    return HighSecurityData(
      guardianAddress: guardianAddress ?? this.guardianAddress,
      safeguardWindow: safeguardWindow ?? this.safeguardWindow,
    );
  }
}
