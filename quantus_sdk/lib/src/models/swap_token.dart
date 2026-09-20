class SwapToken {
  final String assetId;
  final String symbol;
  final String network;
  final int decimals;
  final double usdPrice;
  final String? iconUrl;
  final String? networkIconUrl;

  const SwapToken({
    required this.assetId,
    required this.symbol,
    required this.network,
    required this.decimals,
    required this.usdPrice,
    this.iconUrl,
    this.networkIconUrl,
  });

  SwapToken copyWith({String? iconUrl, String? networkIconUrl}) => SwapToken(
    assetId: assetId,
    symbol: symbol,
    network: network,
    decimals: decimals,
    usdPrice: usdPrice,
    iconUrl: iconUrl ?? this.iconUrl,
    networkIconUrl: networkIconUrl ?? this.networkIconUrl,
  );

  @override
  bool operator ==(Object other) => other is SwapToken && assetId == other.assetId;

  @override
  int get hashCode => assetId.hashCode;
}
