class ReferralData {
  final int id;
  final String referrerAddress;
  final String refereeAddress;
  final DateTime createdAt;

  ReferralData({
    required this.id,
    required this.referrerAddress,
    required this.refereeAddress,
    required this.createdAt,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    return ReferralData(
      id: json['data']['id'] as int,
      referrerAddress: json['data']['referrer_address'] as String,
      refereeAddress: json['data']['referee_address'] as String,
      createdAt: DateTime.parse(json['data']['created_at'] as String),
    );
  }

  @override
  String toString() {
    return 'ReferralData{id: $id, referrerAddress: $referrerAddress, refereeAddress: $refereeAddress, createdAt: $createdAt}';
  }
}
