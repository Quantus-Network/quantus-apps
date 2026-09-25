import 'package:quantus_sdk/src/constants/app_constants.dart';

class SwapToken {
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

  const SwapToken({
    required this.assetId,
    required this.symbol,
    required this.network,
    required this.decimals,
    required this.usdPrice,
    this.iconUrl,
    this.networkIconUrl,
  });

  bool get isQuantus => assetId == AppConstants.quantusIntentsAssetId;

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
  );

  @override
  bool operator ==(Object other) => other is SwapToken && assetId == other.assetId;

  @override
  int get hashCode => assetId.hashCode;
}
