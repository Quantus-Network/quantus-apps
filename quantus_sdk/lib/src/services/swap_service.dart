import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/models/swap_order.dart';
import 'package:quantus_sdk/src/models/swap_quote.dart';
import 'package:quantus_sdk/src/models/swap_token.dart';
import 'package:quantus_sdk/src/utils/print.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1Click answered [statusCode] with [message].
class SwapApiException implements Exception {
  final int statusCode;
  final String message;

  const SwapApiException(this.statusCode, this.message);

  @override
  String toString() => 'SwapApiException($statusCode): $message';
}

/// Client for the NEAR Intents 1Click API. A quote names a deposit address on
/// the origin chain; whatever the user sends there before the deadline is
/// swapped by solvers and paid out to the recipient, or refunded. Nothing in
/// the app ever holds or signs the swapped funds.
class SwapService {
  static const defaultSlippageBps = 100;
  static const depositWindow = Duration(minutes: 20);
  static const quoteWaitingTime = Duration(seconds: 3);
  static const statusPollInterval = Duration(seconds: 5);
  static const _savedAddressesKey = 'swap_saved_addresses';
  static const _maxSavedAddresses = 50;
  static const _coinGeckoTopUrl =
      'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=150&page=1&sparkline=false';
  static const _tokensCacheTtl = Duration(minutes: 10);

  final http.Client _client;
  final Uri _base;
  final String? _apiKey;
  List<SwapToken>? _cachedFromTokens;
  DateTime? _cachedFromTokensAt;

  SwapService({http.Client? client, String endpoint = AppConstants.oneClickEndpoint, String? apiKey})
    : _client = client ?? http.Client(),
      _base = Uri.parse(endpoint),
      _apiKey = apiKey;

  static SwapToken quantusToken({required double usdPrice}) => SwapToken(
    assetId: AppConstants.quantusIntentsAssetId,
    symbol: AppConstants.tokenSymbol,
    network: 'Quantus',
    decimals: AppConstants.decimals,
    usdPrice: usdPrice,
  );

  Future<List<SwapToken>> getFromTokens({int limit = 10, bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cached = _cachedFromTokens;
    if (!forceRefresh && cached != null && now.difference(_cachedFromTokensAt!) < _tokensCacheTtl) {
      return cached.take(limit).toList();
    }
    final tokens = await _rankByCoinGecko(await _fetchIntentsTokens());
    _cachedFromTokens = tokens;
    _cachedFromTokensAt = now;
    return tokens.take(limit).toList();
  }

  /// Asks solvers for a price on [amount] base units of [from]. A dry quote is
  /// a preview; a live one reserves a deposit address until its deadline.
  Future<SwapQuote> getQuote({
    required SwapToken from,
    required SwapToken to,
    required BigInt amount,
    required String refundAddress,
    required String recipient,
    int slippageBps = defaultSlippageBps,
    bool dry = true,
  }) async {
    final json = await _send(
      'POST',
      '/v0/quote',
      body: {
        'dry': dry,
        'swapType': 'EXACT_INPUT',
        'slippageTolerance': slippageBps,
        'originAsset': from.assetId,
        'depositType': 'ORIGIN_CHAIN',
        'destinationAsset': to.assetId,
        'amount': amount.toString(),
        'refundTo': refundAddress,
        'refundType': 'ORIGIN_CHAIN',
        'recipient': recipient,
        'recipientType': 'DESTINATION_CHAIN',
        'deadline': DateTime.now().toUtc().add(depositWindow).toIso8601String(),
        'quoteWaitingTimeMs': quoteWaitingTime.inMilliseconds,
      },
    );
    return SwapQuote.fromJson(json as Map<String, dynamic>, fromToken: from, toToken: to);
  }

  /// Re-quotes [quote] live so 1Click reserves a deposit address for it.
  Future<SwapOrder> createSwap(SwapQuote quote) async {
    final live = await getQuote(
      from: quote.fromToken,
      to: quote.toToken,
      amount: quote.amountIn,
      refundAddress: quote.refundAddress,
      recipient: quote.recipient,
      slippageBps: quote.slippageBps,
      dry: false,
    );
    if (live.depositAddress == null) throw StateError('Live quote ${live.correlationId} has no deposit address');
    return SwapOrder(quote: live, status: SwapStatus.pendingDeposit);
  }

  /// Tells 1Click which transaction paid [order]'s deposit address, so it
  /// does not have to wait for its own chain scan to notice the deposit.
  Future<void> submitDeposit(SwapOrder order, String txHash) async {
    final memo = order.quote.depositMemo;
    await _send(
      'POST',
      '/v0/deposit/submit',
      body: {'txHash': txHash, 'depositAddress': order.depositAddress, 'memo': ?memo},
    );
  }

  Future<SwapOrder> getSwapStatus(SwapOrder order) async {
    final memo = order.quote.depositMemo;
    final json = await _send(
      'GET',
      '/v0/status',
      query: {'depositAddress': order.depositAddress, 'depositMemo': ?memo},
    );
    return SwapOrder.fromStatusJson(json as Map<String, dynamic>, quote: order.quote);
  }

  Future<Object?> _send(String method, String path, {Map<String, Object>? body, Map<String, String>? query}) async {
    final uri = _base.replace(path: path, queryParameters: query);
    final headers = {'Content-Type': 'application/json', 'X-API-Key': ?_apiKey};
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(uri, headers: headers, body: jsonEncode(body));
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      if (ok) rethrow;
    }
    if (!ok) {
      final message = json is Map ? json['message'] : null;
      throw SwapApiException(response.statusCode, switch (message) {
        String s => s,
        List l => l.join(', '),
        _ => response.body,
      });
    }
    return json;
  }

  Future<List<SwapToken>> _fetchIntentsTokens() async {
    final data = await _send('GET', '/v0/tokens') as List<dynamic>;
    final bySymbol = <String, SwapToken>{};
    for (final item in data.cast<Map<String, dynamic>>()) {
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      if (price <= 0) continue;
      final network = (item['blockchain'] as String).toUpperCase();
      final token = SwapToken(
        assetId: item['assetId'] as String,
        symbol: (item['symbol'] as String).toUpperCase(),
        network: network,
        decimals: (item['decimals'] as num).toInt(),
        usdPrice: price,
        networkIconUrl: _networkIconUrl(network),
      );
      if (token.symbol == AppConstants.tokenSymbol) continue;
      final existing = bySymbol[token.symbol];
      if (existing == null || _networkPriority(token.network) < _networkPriority(existing.network)) {
        bySymbol[token.symbol] = token;
      }
    }
    return bySymbol.values.toList();
  }

  /// Orders [tokens] by CoinGecko market cap and picks up their icons. A
  /// CoinGecko failure only costs the ordering, so it is logged, not thrown.
  Future<List<SwapToken>> _rankByCoinGecko(List<SwapToken> tokens) async {
    final rankBySymbol = <String, int>{};
    final iconBySymbol = <String, String>{};
    try {
      final response = await _client.get(Uri.parse(_coinGeckoTopUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SwapApiException(response.statusCode, response.body);
      }
      final payload = jsonDecode(response.body) as List<dynamic>;
      for (var i = 0; i < payload.length; i++) {
        final item = payload[i] as Map<String, dynamic>;
        final symbol = (item['symbol'] as String).toUpperCase();
        if (rankBySymbol.containsKey(symbol)) continue;
        rankBySymbol[symbol] = i;
        final icon = item['image'] as String?;
        if (icon != null && icon.isNotEmpty) iconBySymbol[symbol] = icon;
      }
    } catch (e) {
      quantusPrint('CoinGecko ranking failed, sorting swap tokens by price: $e');
    }
    final ranked = [
      for (final token in tokens)
        token.copyWith(iconUrl: iconBySymbol[token.symbol] ?? _fallbackTokenIconUrl(token.symbol)),
    ];
    ranked.sort((a, b) {
      final ar = rankBySymbol[a.symbol] ?? 99999;
      final br = rankBySymbol[b.symbol] ?? 99999;
      if (ar != br) return ar.compareTo(br);
      return b.usdPrice.compareTo(a.usdPrice);
    });
    return ranked;
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

  /// Remembers [address] on [network] for future swaps, most recent first.
  Future<void> saveAddress(String network, String address) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _savedAddressesStorageKey(network);
    final addresses = [address, ...?prefs.getStringList(key)?.where((a) => a != address)];
    await prefs.setStringList(key, addresses.take(_maxSavedAddresses).toList());
  }

  Future<List<String>> getSavedAddresses(String network) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedAddressesStorageKey(network)) ?? [];
  }

  static String _savedAddressesStorageKey(String network) => '${_savedAddressesKey}_${network.toLowerCase()}';
}
