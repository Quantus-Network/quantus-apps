import 'dart:convert';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum SwapStatus { pending, depositing, processing, complete, failed, expired }

class SwapToken {
  final String symbol;
  final String name;
  final String network;
  final int decimals;
  final String? iconUrl;
  final String? networkIconUrl;

  const SwapToken({
    required this.symbol,
    required this.name,
    required this.network,
    this.decimals = 18,
    this.iconUrl,
    this.networkIconUrl,
  });

  @override
  bool operator ==(Object other) => other is SwapToken && symbol == other.symbol && network == other.network;

  @override
  int get hashCode => Object.hash(symbol, network);
}

class SwapQuote {
  final String quoteId;
  final SwapToken fromToken;
  final SwapToken toToken;
  final double fromAmount;
  final double toAmount;
  final double rate;
  final double networkFee;
  final double totalAmount;
  final double slippageTolerance;
  final Duration expiresIn;

  const SwapQuote({
    required this.quoteId,
    required this.fromToken,
    required this.toToken,
    required this.fromAmount,
    required this.toAmount,
    required this.rate,
    required this.networkFee,
    required this.totalAmount,
    required this.slippageTolerance,
    required this.expiresIn,
  });
}

class SwapOrder {
  final String orderId;
  final SwapQuote quote;
  final String depositAddress;
  final SwapStatus status;
  final DateTime createdAt;

  const SwapOrder({
    required this.orderId,
    required this.quote,
    required this.depositAddress,
    required this.status,
    required this.createdAt,
  });

  SwapOrder copyWith({SwapStatus? status}) => SwapOrder(
    orderId: orderId,
    quote: quote,
    depositAddress: depositAddress,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}

class SwapService {
  static final SwapService _instance = SwapService._();
  factory SwapService() => _instance;
  SwapService._();

  static const _refundAddressKey = 'recent_refund_addresses';
  static const _maxRefundAddresses = 50;
  static const _intentsTokensUrl = 'https://1click.chaindefuser.com/v0/tokens';
  static const _coinGeckoTopUrl =
      'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=150&page=1&sparkline=false';
  static const _tokensCacheTtl = Duration(minutes: 10);
  final _orders = <String, SwapOrder>{};
  List<SwapToken>? _cachedFromTokens;
  DateTime? _cachedFromTokensAt;
  Map<String, double> _liveUsdPriceBySymbol = {};

  static const availableTokens = [
    SwapToken(symbol: 'USDC', name: 'USD Coin', network: 'Ethereum'),
    SwapToken(symbol: 'USDT', name: 'Tether', network: 'Ethereum'),
    SwapToken(symbol: 'ETH', name: 'Ethereum', network: 'Ethereum'),
    SwapToken(symbol: 'BTC', name: 'Bitcoin', network: 'Bitcoin', decimals: 8),
    SwapToken(symbol: 'SOL', name: 'Solana', network: 'Solana', decimals: 9),
    SwapToken(symbol: 'QUAN', name: 'Quantus', network: 'Quantus'),
  ];

  static const _quToken = SwapToken(symbol: 'QUAN', name: 'Quantus', network: 'Quantus');

  Future<List<SwapToken>> getFromTokens({int limit = 10, bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedFromTokens != null &&
        _cachedFromTokensAt != null &&
        now.difference(_cachedFromTokensAt!) < _tokensCacheTtl) {
      return _cachedFromTokens!.take(limit).toList();
    }

    try {
      final intentTokens = await _fetchNearIntentsTokens();
      if (intentTokens.isNotEmpty) {
        final ranked = await _rankByCoinGecko(intentTokens);
        _cachedFromTokens = ranked;
        _cachedFromTokensAt = now;
        _liveUsdPriceBySymbol = {for (final token in ranked) token.symbol.toUpperCase(): token.price};
        return ranked.take(limit).toList();
      }
    } catch (_) {}

    final fallback = availableTokens.where((t) => t.symbol != 'QUAN').take(limit).toList();
    _cachedFromTokens = fallback;
    _cachedFromTokensAt = now;
    return fallback;
  }

  SwapToken getQuToken() => _quToken;

  static String formatTokenAmount(double amount, SwapToken token) {
    if (amount == 0) return '0';
    final decimals = token.decimals.clamp(0, 12);
    var s = amount.toStringAsFixed(decimals).replaceAll(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  static String formatTokenAmountHint(SwapToken token) {
    if (token.decimals == 0) return '0';
    return '0.${'0' * token.decimals.clamp(1, 8)}';
  }

  String? getTokenIconUrl(SwapToken token) {
    final cached = _cachedFromTokens?.where((t) => t.symbol == token.symbol && t.network == token.network).firstOrNull;
    if (cached?.iconUrl != null && cached!.iconUrl!.isNotEmpty) return cached.iconUrl;
    return _fallbackTokenIconUrl(token.symbol);
  }

  String? getNetworkIconUrl(SwapToken token) {
    final cached = _cachedFromTokens?.where((t) => t.symbol == token.symbol && t.network == token.network).firstOrNull;
    if (cached?.networkIconUrl != null && cached!.networkIconUrl!.isNotEmpty) return cached.networkIconUrl;
    return _networkIconUrl(token.network);
  }

  double getRate(SwapToken from) {
    final fromUsd = getUsdPrice(from);
    final toUsd = getUsdPrice(_quToken);
    if (fromUsd <= 0 || toUsd <= 0) return 1.0;
    return fromUsd / toUsd;
  }

  double getUsdPrice(SwapToken token) {
    final livePrice = _liveUsdPriceBySymbol[token.symbol.toUpperCase()];
    if (livePrice != null && livePrice > 0) return livePrice;
    switch (token.symbol.toUpperCase()) {
      case 'USDC':
      case 'USDT':
        return 1.0;
      case 'ETH':
        return 2500.0;
      case 'BTC':
        return 60000.0;
      case 'SOL':
        return 150.0;
      case 'QUAN':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Future<List<_IntentToken>> _fetchNearIntentsTokens() async {
    final response = await http.get(Uri.parse(_intentsTokensUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch intents tokens');
    }
    final data = jsonDecode(response.body);
    if (data is! List) return const [];

    final bySymbol = <String, _IntentToken>{};
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final symbolRaw = item['symbol'];
      final blockchainRaw = item['blockchain'];
      final decimalsRaw = item['decimals'];
      final priceRaw = item['price'];
      if (symbolRaw is! String || symbolRaw.isEmpty) continue;
      if (blockchainRaw is! String || blockchainRaw.isEmpty) continue;
      final symbol = symbolRaw.toUpperCase();
      if (symbol == 'QUAN') continue;
      final price = (priceRaw as num?)?.toDouble() ?? 0;
      if (price <= 0) continue;
      final decimals = (decimalsRaw as num?)?.toInt() ?? 18;
      final token = _IntentToken(
        symbol: symbol,
        network: blockchainRaw.toUpperCase(),
        decimals: decimals,
        price: price,
        networkIconUrl: _networkIconUrl(blockchainRaw.toUpperCase()),
      );
      final existing = bySymbol[symbol];
      if (existing == null || _networkPriority(token.network) < _networkPriority(existing.network)) {
        bySymbol[symbol] = token;
      }
    }
    return bySymbol.values.toList();
  }

  Future<List<_IntentToken>> _rankByCoinGecko(List<_IntentToken> tokens) async {
    try {
      final response = await http.get(Uri.parse(_coinGeckoTopUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _sortByPrice(tokens);
      }
      final payload = jsonDecode(response.body);
      if (payload is! List) return _sortByPrice(tokens);
      final rankBySymbol = <String, int>{};
      final iconBySymbol = <String, String>{};
      for (var i = 0; i < payload.length; i++) {
        final item = payload[i];
        if (item is! Map<String, dynamic>) continue;
        final symbol = (item['symbol'] as String?)?.toUpperCase();
        if (symbol == null || symbol.isEmpty || rankBySymbol.containsKey(symbol)) {
          continue;
        }
        rankBySymbol[symbol] = i;
        final icon = item['image'] as String?;
        if (icon != null && icon.isNotEmpty) iconBySymbol[symbol] = icon;
      }
      final ranked = [
        for (final token in tokens)
          token.copyWith(iconUrl: iconBySymbol[token.symbol] ?? token.iconUrl ?? _fallbackTokenIconUrl(token.symbol)),
      ];
      ranked.sort((a, b) {
        final ar = rankBySymbol[a.symbol] ?? 99999;
        final br = rankBySymbol[b.symbol] ?? 99999;
        if (ar != br) return ar.compareTo(br);
        return b.price.compareTo(a.price);
      });
      return ranked;
    } catch (_) {
      return _sortByPrice(tokens);
    }
  }

  List<_IntentToken> _sortByPrice(List<_IntentToken> tokens) {
    final sorted = [...tokens];
    sorted.sort((a, b) => b.price.compareTo(a.price));
    return sorted;
  }

  int _networkPriority(String network) {
    switch (network) {
      case 'ETH':
        return 0;
      case 'BTC':
        return 1;
      case 'SOL':
        return 2;
      case 'NEAR':
        return 3;
      case 'BASE':
        return 4;
      case 'ARB':
        return 5;
      default:
        return 100;
    }
  }

  String? _fallbackTokenIconUrl(String symbol) {
    switch (symbol) {
      case 'USDC':
        return 'https://assets.coingecko.com/coins/images/6319/large/usdc.png';
      case 'USDT':
        return 'https://assets.coingecko.com/coins/images/325/large/Tether.png';
      case 'ETH':
      case 'WETH':
        return 'https://assets.coingecko.com/coins/images/279/large/ethereum.png';
      case 'BTC':
      case 'WBTC':
      case 'XBTC':
        return 'https://assets.coingecko.com/coins/images/1/large/bitcoin.png';
      case 'SOL':
        return 'https://assets.coingecko.com/coins/images/4128/large/solana.png';
      case 'NEAR':
      case 'WNEAR':
        return 'https://assets.coingecko.com/coins/images/10365/large/near.jpg';
      default:
        return null;
    }
  }

  String? _networkIconUrl(String network) {
    switch (network) {
      case 'ETH':
      case 'BASE':
      case 'ARB':
      case 'OP':
      case 'GNOSIS':
      case 'AVAX':
      case 'POL':
      case 'MONAD':
      case 'BSC':
        return 'https://assets.coingecko.com/coins/images/279/large/ethereum.png';
      case 'BTC':
        return 'https://assets.coingecko.com/coins/images/1/large/bitcoin.png';
      case 'SOL':
        return 'https://assets.coingecko.com/coins/images/4128/large/solana.png';
      case 'NEAR':
        return 'https://assets.coingecko.com/coins/images/10365/large/near.jpg';
      default:
        return null;
    }
  }

  Future<SwapQuote> getQuote({required SwapToken fromToken, required double fromAmount, double slippage = 0.01}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final rate = getRate(fromToken);
    final toAmount = fromAmount * rate;
    final networkFee = fromAmount * 0.005;
    final totalAmount = fromAmount + networkFee;

    return SwapQuote(
      quoteId: 'quote_${DateTime.now().millisecondsSinceEpoch}',
      fromToken: fromToken,
      toToken: _quToken,
      fromAmount: fromAmount,
      toAmount: toAmount,
      rate: rate,
      networkFee: networkFee,
      totalAmount: totalAmount,
      slippageTolerance: slippage,
      expiresIn: const Duration(minutes: 5),
    );
  }

  Future<SwapOrder> createSwap(SwapQuote quote) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final rng = Random();
    final hex = List.generate(40, (_) => rng.nextInt(16).toRadixString(16)).join();
    final order = SwapOrder(
      orderId: 'swap_${DateTime.now().millisecondsSinceEpoch}',
      quote: quote,
      depositAddress: '0x$hex',
      status: SwapStatus.depositing,
      createdAt: DateTime.now(),
    );
    _orders[order.orderId] = order;
    return order;
  }

  Future<SwapOrder> getSwapStatus(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final order = _orders[orderId];
    if (order == null) throw Exception('Order not found');
    return order;
  }

  Future<SwapOrder> confirmFundsSent(String orderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final order = _orders[orderId];
    if (order == null) throw Exception('Order not found');
    final updated = order.copyWith(status: SwapStatus.processing);
    _orders[orderId] = updated;

    Future.delayed(const Duration(seconds: 5), () {
      if (_orders.containsKey(orderId)) {
        _orders[orderId] = _orders[orderId]!.copyWith(status: SwapStatus.complete);
      }
    });

    return updated;
  }

  Future<void> addRefundAddress(String network, String address) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_refundAddressKey}_${network.toLowerCase()}';
    var addresses = prefs.getStringList(key) ?? [];
    addresses.remove(address);
    addresses.insert(0, address);
    if (addresses.length > _maxRefundAddresses) {
      addresses = addresses.sublist(0, _maxRefundAddresses);
    }
    await prefs.setStringList(key, addresses);
  }

  Future<List<String>> getRefundAddresses(String network) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_refundAddressKey}_${network.toLowerCase()}';
    return prefs.getStringList(key) ?? [];
  }
}

class _IntentToken extends SwapToken {
  final double price;
  const _IntentToken({
    required super.symbol,
    required super.network,
    required super.decimals,
    required this.price,
    super.iconUrl,
    super.networkIconUrl,
  }) : super(name: symbol);

  _IntentToken copyWith({String? iconUrl, String? networkIconUrl}) {
    return _IntentToken(
      symbol: symbol,
      network: network,
      decimals: decimals,
      price: price,
      iconUrl: iconUrl ?? this.iconUrl,
      networkIconUrl: networkIconUrl ?? this.networkIconUrl,
    );
  }
}
