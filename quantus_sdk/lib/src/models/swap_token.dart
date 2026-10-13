class SwapToken {
  /// Network code 1Click gives the Quantus chain (`qtc`, upper-cased here);
  /// the token listed on it is QTC. QTC is also listed on NEAR itself, which
  /// is neither Quantus nor a token to swap with.
  static const quantusNetwork = 'QTC';

  /// Each chain 1Click lists on, by its code: the name shown, and the
  /// CoinGecko id whose logo stands for it, an asset platform or, for a coin's
  /// own chain, the coin.
  static const _networks = <String, ({String name, String? logoId})>{
    'ABS': (name: 'Abstract', logoId: 'abstract'),
    'ADI': (name: 'ADI Chain', logoId: 'adi-chain'),
    'ALEO': (name: 'Aleo', logoId: 'aleo'),
    'APTOS': (name: 'Aptos', logoId: 'aptos'),
    'ARB': (name: 'Arbitrum', logoId: 'arbitrum-one'),
    'AVAX': (name: 'Avalanche', logoId: 'avalanche'),
    'BASE': (name: 'Base', logoId: 'base'),
    'BCH': (name: 'Bitcoin Cash', logoId: 'bitcoin-cash'),
    'BERA': (name: 'Berachain', logoId: 'berachain'),
    'BSC': (name: 'BNB Chain', logoId: 'binance-smart-chain'),
    'BTC': (name: 'Bitcoin', logoId: 'bitcoin'),
    'CARDANO': (name: 'Cardano', logoId: 'cardano'),
    'DASH': (name: 'Dash', logoId: 'dash'),
    'DOGE': (name: 'Dogecoin', logoId: 'dogecoin'),
    'ETH': (name: 'Ethereum', logoId: 'ethereum'),
    'FOGO': (name: 'Fogo', logoId: 'fogo'),
    'GNOSIS': (name: 'Gnosis', logoId: 'xdai'),
    'HOOD': (name: 'Robinhood Chain', logoId: 'robinhood'),
    'HYPERCORE': (name: 'Hyperliquid', logoId: 'hyperliquid'),
    'LTC': (name: 'Litecoin', logoId: 'litecoin'),
    'MONAD': (name: 'Monad', logoId: 'monad'),
    'MOVEMENT': (name: 'Movement', logoId: 'movement'),
    'NEAR': (name: 'NEAR', logoId: 'near-protocol'),
    'OP': (name: 'Optimism', logoId: 'optimistic-ethereum'),
    'PLASMA': (name: 'Plasma', logoId: 'plasma'),
    'POL': (name: 'Polygon', logoId: 'polygon-pos'),
    'QTC': (name: 'Quantus', logoId: null),
    'SCROLL': (name: 'Scroll', logoId: 'scroll'),
    'SOL': (name: 'Solana', logoId: 'solana'),
    'STARKNET': (name: 'Starknet', logoId: 'starknet'),
    'STELLAR': (name: 'Stellar', logoId: 'stellar'),
    'SUI': (name: 'Sui', logoId: 'sui'),
    'TON': (name: 'TON', logoId: 'the-open-network'),
    'TRON': (name: 'Tron', logoId: 'tron'),
    'XLAYER': (name: 'X Layer', logoId: 'x-layer'),
    'XRP': (name: 'XRP Ledger', logoId: 'xrp'),
    'ZEC': (name: 'Zcash', logoId: 'zcash'),
  };

  /// CoinGecko id of [network]'s logo; null for a chain it has none for.
  static String? networkLogoId(String network) => _networks[network]?.logoId;

  final String assetId;
  final String symbol;
  final String network;
  final int decimals;
  final double usdPrice;

  /// The listing on NEAR whose token metadata carries this symbol's logo: this
  /// one when it has a NEAR contract, else another listing of the symbol that
  /// does; null when none does.
  final String? iconAssetId;

  /// CoinGecko's logo of this token's coin; null when CoinGecko has none.
  final String? imageUrl;

  /// CoinGecko's logo of [network]; null when it has none.
  final String? networkImageUrl;

  /// QTC's side of a swap: the token that is QTC, or stands in for it.
  final bool isQuantus;

  const SwapToken({
    required this.assetId,
    required this.symbol,
    required this.network,
    required this.decimals,
    required this.usdPrice,
    this.iconAssetId,
    this.imageUrl,
    this.networkImageUrl,
    this.isQuantus = false,
  });

  /// Whether [assetId] names a token contract on NEAR (NEP-141 or NEP-245).
  static bool hasNearContract(String assetId) => assetId.startsWith('nep141:') || assetId.startsWith('nep245:');

  /// Human name of [network], e.g. "Ethereum" for ETH; the code itself when unknown.
  String get networkName => _networks[network]?.name ?? network;

  @override
  bool operator ==(Object other) => other is SwapToken && assetId == other.assetId;

  @override
  int get hashCode => assetId.hashCode;
}
