class SwapToken {
  /// Network code 1Click gives the Quantus chain (`qtc`, upper-cased here);
  /// the token listed on it is QTC. QTC is also listed on NEAR itself, which
  /// is neither Quantus nor a token to swap with.
  static const quantusNetwork = 'QTC';

  static const _networkNames = {
    'ARB': 'Arbitrum',
    'AVAX': 'Avalanche',
    'BASE': 'Base',
    'BCH': 'Bitcoin Cash',
    'BERA': 'Berachain',
    'BSC': 'BNB Chain',
    'BTC': 'Bitcoin',
    'CARDANO': 'Cardano',
    'DOGE': 'Dogecoin',
    'ETH': 'Ethereum',
    'GNOSIS': 'Gnosis',
    'LTC': 'Litecoin',
    'MONAD': 'Monad',
    'OP': 'Optimism',
    'POL': 'Polygon',
    'QTC': 'Quantus',
    'SOL': 'Solana',
    'STELLAR': 'Stellar',
    'SUI': 'Sui',
    'TRON': 'Tron',
    'ZEC': 'Zcash',
  };

  final String assetId;
  final String symbol;
  final String network;
  final int decimals;
  final double usdPrice;
  final String? iconUrl;
  final String? networkIconUrl;

  /// QTC's side of a swap: the token that is QTC, or stands in for it.
  final bool isQuantus;

  const SwapToken({
    required this.assetId,
    required this.symbol,
    required this.network,
    required this.decimals,
    required this.usdPrice,
    this.iconUrl,
    this.networkIconUrl,
    this.isQuantus = false,
  });

  /// Human name of [network], e.g. "Ethereum" for ETH; the code itself when unknown.
  String get networkName => _networkNames[network] ?? network;

  SwapToken copyWith({String? iconUrl, String? networkIconUrl}) => SwapToken(
    assetId: assetId,
    symbol: symbol,
    network: network,
    decimals: decimals,
    usdPrice: usdPrice,
    iconUrl: iconUrl ?? this.iconUrl,
    networkIconUrl: networkIconUrl ?? this.networkIconUrl,
    isQuantus: isQuantus,
  );

  @override
  bool operator ==(Object other) => other is SwapToken && assetId == other.assetId;

  @override
  int get hashCode => assetId.hashCode;
}
