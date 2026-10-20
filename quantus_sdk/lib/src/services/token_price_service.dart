import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:quantus_sdk/src/services/swap_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// QTC's USD price as the swap provider lists it.
abstract final class TokenPriceService {
  /// An unchanged listing costs the provider a 304, so refreshing is cheap.
  static const refreshInterval = Duration(minutes: 5);

  /// Emits the price now and every [interval]. A failed refresh is logged and
  /// the last price stands; nothing is emitted until the first one lands.
  static Stream<Decimal> watchUsdPrice(SwapService swap, {Duration interval = refreshInterval}) {
    final prices = StreamController<Decimal>();
    Timer? timer;

    Future<void> refresh() async {
      try {
        final listed = await swap.getListedQuantusToken(forceRefresh: true);
        if (listed != null && !prices.isClosed) prices.add(Decimal.parse(listed.usdPrice.toString()));
      } catch (e) {
        quantusPrint('QTC price refresh failed: $e');
      }
    }

    prices.onListen = () {
      timer = Timer.periodic(interval, (_) => refresh());
      unawaited(refresh());
    };
    prices.onCancel = () {
      timer?.cancel();
      prices.close();
    };
    return prices.stream;
  }
}
