import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/models/swap_order.dart';
import 'package:quantus_sdk/src/models/swap_quote.dart';
import 'package:quantus_sdk/src/models/swap_token.dart';
import 'package:quantus_sdk/src/services/coin_gecko_service.dart';
import 'package:quantus_sdk/src/services/one_click_quote_signature.dart';
import 'package:quantus_sdk/src/services/one_click_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A quote response whose signature is not 1Click's, or which answers a
/// different request than the one sent.
class SwapQuoteIntegrityException implements Exception {
  final String message;
  final String? correlationId;

  const SwapQuoteIntegrityException(this.message, {this.correlationId});

  @override
  String toString() => 'SwapQuoteIntegrityException($correlationId): $message';
}

/// Client for the NEAR Intents 1Click API. A quote names a deposit address on
/// the origin chain; whatever the user sends there before the deadline is
/// swapped by solvers and paid out to the recipient, or refunded. Nothing in
/// the app ever holds or signs the swapped funds.
class SwapService {
  static const defaultSlippageBps = 100;
  static const depositWindow = Duration(minutes: 20);

  /// Chains whose blocks take minutes and need several confirmations, so a
  /// correctly sent deposit can take an hour to count.
  static const _slowNetworks = {'BTC', 'LTC', 'DOGE', 'BCH', 'DASH', 'ZEC'};
  static const _slowDepositWindow = Duration(hours: 2);

  /// Least time a live quote's deposit address must stay valid, so a deposit
  /// signed now still lands before the address goes cold.
  static const minimumDepositLead = Duration(minutes: 5);

  /// Chains whose deposits carry a memo; 1Click rejects a plain deposit
  /// address for them and a memo request for every other chain.
  static const _memoNetworks = {'STELLAR'};
  static const _liveQuotesKey = 'swap_live_quotes';
  static const _maxLiveQuotes = 50;

  /// QTC is quoted only as a Confidential Intents swap: a public quote
  /// answers "No liquidity available" whatever the market holds.
  static const confidentiality = 'basic';

  /// Request fields 1Click echoes back that must match what was sent, so a
  /// signed quote is a quote for this swap and not another.
  static const _echoedFields = [
    'dry',
    'swapType',
    'originAsset',
    'destinationAsset',
    'amount',
    'refundTo',
    'recipient',
    'slippageTolerance',
    'confidentiality',
  ];
  static const quoteWaitingTime = Duration(seconds: 3);
  static const statusPollInterval = Duration(seconds: 5);
  static const _savedAddressesKey = 'swap_saved_addresses';
  static const _maxSavedAddresses = 50;
  static const _tokensCacheTtl = Duration(minutes: 10);

  final OneClickService _api;
  final CoinGeckoService _coinGecko;
  final String _managerPublicKey;
  final String? _configuredQuantusAssetId;
  final bool _preflight;
  final int _feeBips;
  (List<SwapToken>, SwapToken?)? _cachedListing;
  DateTime? _cachedListingAt;

  /// [quantusAssetId] names the listing that is QTC when its chain code does
  /// not; it comes from remote config so a surprising listing needs no update.
  /// In [preflight] it names another listed asset standing in for QTC, which
  /// keeps its own network and decimals. [feeBips] is the app's fee on each
  /// swap, in basis points of the input; 0 sends none.
  SwapService({
    http.Client? client,
    String endpoint = AppConstants.oneClickEndpoint,
    String? apiKey,
    String managerPublicKey = AppConstants.oneClickManagerPublicKey,
    String? quantusAssetId,
    bool preflight = false,
    required int feeBips,
  }) : _api = OneClickService(client: client, endpoint: endpoint, apiKey: apiKey),
       _coinGecko = CoinGeckoService(client: client),
       _managerPublicKey = managerPublicKey,
       _configuredQuantusAssetId = quantusAssetId,
       _preflight = preflight,
       _feeBips = feeBips;

  Map<String, Object>? get _appFee =>
      _feeBips > 0 ? {'recipient': AppConstants.oneClickFeeRecipient, 'fee': _feeBips} : null;

  /// How long a deposit on [network] has before its quote expires.
  static Duration depositWindowFor(String network) =>
      _slowNetworks.contains(network) ? _slowDepositWindow : depositWindow;

  /// The tokens to swap between: QTC first, USDC second, then each token's
  /// main listing by market cap, then its listings on other chains.
  Future<List<SwapToken>> getFromTokens({bool forceRefresh = false}) async {
    final (tokens, quantus) = await _listing(forceRefresh: forceRefresh);
    final usdc = tokens.where((t) => t.symbol == 'USDC').firstOrNull;
    return [?quantus, ?usdc, ...tokens.where((t) => t != usdc)];
  }

  /// QTC as 1Click lists it, with its asset id, decimals and price; null until
  /// it is listed with a price, and swaps are unavailable until then.
  Future<SwapToken?> getListedQuantusToken({bool forceRefresh = false}) async =>
      (await _listing(forceRefresh: forceRefresh)).$2;

  Future<(List<SwapToken>, SwapToken?)> _listing({required bool forceRefresh}) async {
    final now = DateTime.now();
    final cached = _cachedListing;
    if (!forceRefresh && cached != null && now.difference(_cachedListingAt!) < _tokensCacheTtl) return cached;
    final listing = await _fetchIntentsTokens();
    _cachedListing = listing;
    _cachedListingAt = now;
    return listing;
  }

  /// Asks solvers for a price on [amount] base units of [from], or of [to] for
  /// an exact output. A dry quote is a preview; a live one reserves a deposit
  /// address until its deadline.
  Future<SwapQuote> getQuote({
    required SwapToken from,
    required SwapToken to,
    required BigInt amount,
    required String refundAddress,
    required String recipient,
    SwapType swapType = SwapType.exactInput,
    int slippageBps = defaultSlippageBps,
    bool dry = true,
  }) async {
    final json = await _quoteJson(
      from: from,
      to: to,
      swapType: swapType,
      amount: amount,
      refundAddress: refundAddress,
      recipient: recipient,
      slippageBps: slippageBps,
      dry: dry,
    );
    return SwapQuote.fromJson(json, fromToken: from, toToken: to);
  }

  /// Re-quotes [quote] live so 1Click reserves a deposit address for it. The
  /// signed response is kept on the device: 1Click settles any dispute about
  /// a deposit address from it.
  Future<SwapOrder> createSwap(SwapQuote quote) async {
    final json = await _quoteJson(
      from: quote.fromToken,
      to: quote.toToken,
      swapType: quote.swapType,
      amount: quote.swapType == SwapType.exactOutput ? quote.amountOut : quote.amountIn,
      refundAddress: quote.refundAddress,
      recipient: quote.recipient,
      slippageBps: quote.slippageBps,
      dry: false,
    );
    final live = SwapQuote.fromJson(json, fromToken: quote.fromToken, toToken: quote.toToken);
    if (live.depositAddress == null) throw StateError('Live quote ${live.correlationId} has no deposit address');
    final lead = live.deadline.difference(DateTime.now());
    if (lead < minimumDepositLead) {
      throw SwapQuoteIntegrityException(
        'Deposit deadline ${live.deadline.toIso8601String()} leaves ${lead.inSeconds}s, need $minimumDepositLead',
        correlationId: live.correlationId,
      );
    }
    await _saveLiveQuote(json);
    return SwapOrder(quote: live, status: SwapStatus.pendingDeposit);
  }

  /// Signed live quote responses, most recent first.
  Future<List<Map<String, dynamic>>> getSavedLiveQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    return [for (final s in prefs.getStringList(_liveQuotesKey) ?? []) jsonDecode(s) as Map<String, dynamic>];
  }

  Future<void> _saveLiveQuote(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = [jsonEncode(json), ...?prefs.getStringList(_liveQuotesKey)];
    await prefs.setStringList(_liveQuotesKey, saved.take(_maxLiveQuotes).toList());
  }

  Future<Map<String, dynamic>> _quoteJson({
    required SwapToken from,
    required SwapToken to,
    required SwapType swapType,
    required BigInt amount,
    required String refundAddress,
    required String recipient,
    required int slippageBps,
    required bool dry,
  }) async {
    await _requireCurrentQuantus(from, to);
    final now = DateTime.now().toUtc();
    final deadline = DateTime.fromMillisecondsSinceEpoch(
      now.add(depositWindowFor(from.network)).millisecondsSinceEpoch,
      isUtc: true,
    );
    final fee = _appFee;
    final body = {
      'dry': dry,
      'swapType': swapType.wire,
      'slippageTolerance': slippageBps,
      'originAsset': from.assetId,
      'depositType': 'ORIGIN_CHAIN',
      'depositMode': _memoNetworks.contains(from.network) ? 'MEMO' : 'SIMPLE',
      'destinationAsset': to.assetId,
      'amount': amount.toString(),
      'refundTo': refundAddress,
      'refundType': 'ORIGIN_CHAIN',
      'recipient': recipient,
      'recipientType': 'DESTINATION_CHAIN',
      'deadline': deadline.toIso8601String(),
      'quoteWaitingTimeMs': quoteWaitingTime.inMilliseconds,
      'referral': AppConstants.oneClickReferral,
      'confidentiality': confidentiality,
      if (fee != null) 'appFees': [fee],
    };
    final json = await _api.send('POST', '/v0/quote', body: body) as Map<String, dynamic>;
    final correlationId = json['correlationId'] as String?;
    if (!OneClickQuoteSignature.verify(json, managerPublicKey: _managerPublicKey)) {
      throw SwapQuoteIntegrityException('Quote signature is not from 1Click', correlationId: correlationId);
    }
    final echoed = json['quoteRequest'] as Map<String, dynamic>;
    for (final field in _echoedFields) {
      if (echoed[field] != body[field]) {
        throw SwapQuoteIntegrityException(
          'Quote answers a different request: $field is ${echoed[field]}, sent ${body[field]}',
          correlationId: correlationId,
        );
      }
    }
    if (fee != null) {
      final fees = (echoed['appFees'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      final sent = fee['fee'] as int;
      if (!fees.any(
        (f) =>
            f['recipient'] == fee['recipient'] &&
            switch (f['fee']) {
              final num share => share >= 1 && share <= sent,
              _ => false,
            },
      )) {
        throw SwapQuoteIntegrityException(
          'Quote answers a different request: appFees are $fees, sent $fee',
          correlationId: correlationId,
        );
      }
    }
    if (!DateTime.parse(echoed['deadline'] as String).isAtSameMomentAs(deadline)) {
      throw SwapQuoteIntegrityException(
        'Quote answers a different request: deadline is ${echoed['deadline']}, sent ${body['deadline']}',
        correlationId: correlationId,
      );
    }
    final fixedField = swapType == SwapType.exactOutput ? 'amountOut' : 'amountIn';
    final fixed = (json['quote'] as Map<String, dynamic>)[fixedField];
    if (fixed != body['amount']) {
      throw SwapQuoteIntegrityException(
        'Quote prices $fixed as $fixedField, sent ${body['amount']}',
        correlationId: correlationId,
      );
    }
    return json;
  }

  /// A token standing for QTC must be QTC as listed right now. A flow that
  /// kept its tokens from before a config change is refused, not quoted.
  Future<void> _requireCurrentQuantus(SwapToken from, SwapToken to) async {
    for (final token in [from, to].where((t) => t.isQuantus)) {
      final listed = await getListedQuantusToken();
      if (listed?.assetId != token.assetId) {
        throw SwapQuoteIntegrityException(
          'QTC is listed as ${listed?.assetId ?? 'nothing'}, this swap was prepared for ${token.assetId}',
        );
      }
    }
  }

  /// Tells 1Click which transaction paid [order]'s deposit address, so it
  /// does not have to wait for its own chain scan to notice the deposit.
  Future<void> submitDeposit(SwapOrder order, String txHash) async {
    final memo = order.quote.depositMemo;
    await _api.send(
      'POST',
      '/v0/deposit/submit',
      body: {'txHash': txHash, 'depositAddress': order.depositAddress, 'memo': ?memo},
    );
  }

  Future<SwapOrder> getSwapStatus(SwapOrder order) async {
    final memo = order.quote.depositMemo;
    final json = await _api.send(
      'GET',
      '/v0/status',
      query: {'depositAddress': order.depositAddress, 'depositMemo': ?memo},
    );
    return SwapOrder.fromStatusJson(json as Map<String, dynamic>, quote: order.quote);
  }

  /// The tokens to swap with, one per symbol and chain, and QTC as listed. A
  /// token is on Quantus when 1Click says so or when its asset id is the
  /// configured one. Each symbol's main listing comes first, by market cap,
  /// then its listings on other chains, by market cap and chain, then the
  /// tokens without a market cap, by chain and in 1Click's order. A token
  /// ranks by the market cap of the CoinGecko coin 1Click names for it only
  /// when that coin carries its symbol: a bridged BTC listed under bitcoin, or
  /// a vault's sUSDC listed under usd-coin, has none. Listings 1Click marks
  /// deprecated are left out, as is a second listing of a symbol on the same
  /// chain.
  Future<(List<SwapToken>, SwapToken?)> _fetchIntentsTokens() async {
    final data = (await _api.send('GET', '/v0/tokens') as List<dynamic>).cast<Map<String, dynamic>>();
    final logoIds = {for (final item in data) ?SwapToken.networkLogoId((item['blockchain'] as String).toUpperCase())};
    final (coins, platformLogos) = await (
      _coinMarkets({for (final item in data) ?item['coingeckoId'] as String?, ...logoIds}),
      _platformLogos(logoIds),
    ).wait;
    final nearBySymbol = <String, String>{};
    for (final item in data) {
      final assetId = item['assetId'] as String;
      if (SwapToken.hasNearContract(assetId)) {
        nearBySymbol.putIfAbsent((item['symbol'] as String).toUpperCase(), () => assetId);
      }
    }
    final listings = <(String, String), SwapToken>{};
    final onQuantus = <SwapToken>[];
    for (final item in data) {
      final assetId = item['assetId'] as String;
      final symbol = (item['symbol'] as String).toUpperCase();
      final chain = (item['blockchain'] as String).toUpperCase();
      final ours = chain == SwapToken.quantusNetwork || assetId == _configuredQuantusAssetId;
      final network = ours && !_preflight ? SwapToken.quantusNetwork : chain;
      final coin = coins[item['coingeckoId']];
      final logoId = SwapToken.networkLogoId(network);
      final token = SwapToken(
        assetId: assetId,
        symbol: symbol,
        network: network,
        decimals: (item['decimals'] as num).toInt(),
        usdPrice: (item['price'] as num?)?.toDouble() ?? 0,
        iconAssetId: SwapToken.hasNearContract(assetId) ? assetId : nearBySymbol[symbol],
        imageUrl: coin?.imageUrl,
        networkImageUrl: platformLogos[logoId] ?? coins[logoId]?.imageUrl,
        marketCapUsd: coin != null && coin.symbol.toUpperCase() == symbol ? coin.marketCapUsd : 0,
        isQuantus: ours,
      );
      if (ours) {
        onQuantus.add(token);
        continue;
      }
      if (token.usdPrice <= 0 || token.symbol == AppConstants.tokenSymbol || symbol.contains('DEPRECATED')) continue;
      listings.putIfAbsent((symbol, network), () => token);
    }
    final main = <String, SwapToken>{};
    for (final token in listings.values) {
      final existing = main[token.symbol];
      if (existing == null || _networkPriority(token) < _networkPriority(existing)) main[token.symbol] = token;
    }
    final mains = main.values.toSet();
    int tier(SwapToken t) => t.marketCapUsd == 0
        ? 2
        : mains.contains(t)
        ? 0
        : 1;
    final tokens = _ordered(listings.values, (t) => [tier(t), -t.marketCapUsd, _networkPriority(t)]);
    return (tokens, _listedQuantusAmong(onQuantus));
  }

  /// The tokens among [tokens] whose symbol, chain code or chain name contains
  /// [query], QTC first, then by market cap and as listed: a search for USDC
  /// shows USDC on every chain before the vault tokens that merely carry its
  /// name. An empty query is the listing itself.
  static List<SwapToken> search(List<SwapToken> tokens, String query) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) return tokens;
    final matches = tokens.where(
      (t) => t.symbol.contains(q) || t.network.contains(q) || t.networkName.toUpperCase().contains(q),
    );
    return _ordered(matches, (t) => [t.isQuantus ? 0 : 1, -t.marketCapUsd]);
  }

  /// [tokens] by [keys], equal keys as given: a total order, so the sort's
  /// own instability never shows.
  static List<SwapToken> _ordered(Iterable<SwapToken> tokens, List<num> Function(SwapToken) keys) {
    final keyed = [
      for (final (i, t) in tokens.indexed) (t, [...keys(t), i]),
    ];
    keyed.sort((a, b) {
      for (var i = 0; i < a.$2.length; i++) {
        final c = a.$2[i].compareTo(b.$2[i]);
        if (c != 0) return c;
      }
      return 0;
    });
    return [for (final (t, _) in keyed) t];
  }

  /// CoinGecko's coins among [ids]; none when CoinGecko fails, which leaves
  /// the tokens in 1Click's order with their logos from NEAR.
  Future<Map<String, CoinMarket>> _coinMarkets(Set<String> ids) async {
    try {
      return await _coinGecko.markets(ids);
    } catch (e) {
      quantusPrint('CoinGecko markets failed, swap tokens stay in 1Click order: $e');
      return const {};
    }
  }

  /// CoinGecko's chain logos among [ids]; none when CoinGecko fails, which
  /// leaves each chain to its letter.
  Future<Map<String, String>> _platformLogos(Set<String> ids) async {
    try {
      return await _coinGecko.platformLogos(ids);
    } catch (e) {
      quantusPrint('CoinGecko chain logos failed, chains show their letter: $e');
      return const {};
    }
  }

  /// QTC among the tokens 1Click lists on Quantus: the configured asset id when
  /// there is one, else the only token, or the only one with QTC's symbol. More
  /// than one candidate is refused rather than guessed, as is a listing whose
  /// decimals differ from the chain's: every quoted amount would be wrong. A
  /// listing without a price does not count as listed.
  SwapToken? _listedQuantusAmong(List<SwapToken> onQuantus) {
    final configured = _configuredQuantusAssetId;
    final SwapToken? listed;
    if (configured != null) {
      listed = onQuantus.where((t) => t.assetId == configured).singleOrNull;
      if (listed == null) quantusPrint('1Click does not list the configured Quantus asset $configured');
    } else if (onQuantus.length <= 1) {
      listed = onQuantus.singleOrNull;
    } else {
      listed = onQuantus.where((t) => t.symbol == AppConstants.tokenSymbol).singleOrNull;
      if (listed == null) {
        throw StateError(
          '1Click lists ${onQuantus.map((t) => t.assetId).join(', ')} on Quantus; set swapQuantusAssetId',
        );
      }
    }
    if (listed == null) return null;
    if (!_preflight && listed.decimals != AppConstants.decimals) {
      throw StateError(
        '1Click lists ${listed.assetId} with ${listed.decimals} decimals, the chain has ${AppConstants.decimals}',
      );
    }
    if (listed.usdPrice <= 0) {
      quantusPrint('1Click lists ${listed.assetId} without a price, swaps stay unavailable');
      return null;
    }
    return listed;
  }

  /// Which listing of a symbol comes first: the coin's own chain (ZEC on
  /// Zcash, wNEAR on NEAR), then the main networks in order.
  int _networkPriority(SwapToken token) {
    if (token.symbol == token.network || token.symbol == 'W${token.network}') return -1;
    return switch (token.network) {
      'ETH' => 0,
      'BTC' => 1,
      'SOL' => 2,
      'TRON' => 3,
      'BSC' => 4,
      'NEAR' => 5,
      'BASE' => 6,
      'ARB' => 7,
      'POL' => 8,
      'OP' => 9,
      'AVAX' => 10,
      _ => 100,
    };
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
