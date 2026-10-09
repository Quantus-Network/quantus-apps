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

  /// The listing on NEAR whose token metadata carries this symbol's logo: this
  /// one when it has a NEAR contract, else another listing of the symbol that
  /// does; null when none does.
  final String? iconAssetId;

  /// QTC's side of a swap: the token that is QTC, or stands in for it.
  final bool isQuantus;

  const SwapToken({
    required this.assetId,
    required this.symbol,
    required this.network,
    required this.decimals,
    required this.usdPrice,
    this.iconAssetId,
    this.isQuantus = false,
  });

  /// Whether [assetId] names a token contract on NEAR (NEP-141 or NEP-245).
  static bool hasNearContract(String assetId) => assetId.startsWith('nep141:') || assetId.startsWith('nep245:');

  /// Human name of [network], e.g. "Ethereum" for ETH; the code itself when unknown.
  String get networkName => _networkNames[network] ?? network;

  @override
  bool operator ==(Object other) => other is SwapToken && assetId == other.assetId;

  @override
  int get hashCode => assetId.hashCode;
}
