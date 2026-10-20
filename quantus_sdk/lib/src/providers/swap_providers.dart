import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/swap_preflight.dart';
import 'package:quantus_sdk/src/providers/remote_config_provider.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// The stand-in for QTC this build was started with; null in every real build.
final swapPreflightProvider = Provider<SwapPreflight?>((_) => SwapPreflight.fromEnvironment);

final swapServiceProvider = Provider<SwapService>((ref) {
  final preflight = ref.watch(swapPreflightProvider);
  final apiKey = ref.watch(remoteConfigProvider.select((c) => c.nearPartnerJwt));
  if (preflight != null) return SwapService(quantusAssetId: preflight.assetId, preflight: true, apiKey: apiKey);
  return SwapService(
    quantusAssetId: ref.watch(remoteConfigProvider.select((c) => c.swapQuantusAssetId)),
    apiKey: apiKey,
  );
});

/// [order] followed through the swap provider's status endpoint until it settles.
final swapOrderProvider = StreamProvider.autoDispose.family<SwapOrder, SwapOrder>((ref, order) async* {
  final service = ref.watch(swapServiceProvider);
  var current = order;
  yield current;
  while (!current.status.isFinal) {
    await Future<void>.delayed(SwapService.statusPollInterval);
    if (!ref.mounted) return;
    try {
      current = await service.getSwapStatus(current);
      yield current;
    } catch (e) {
      quantusPrint('Swap status poll failed: $e');
    }
  }
});

final swapTokenIconServiceProvider = Provider<SwapTokenIconService>((ref) => SwapTokenIconService());

/// [token]'s logo; null while it loads, when there is none, or when the fetch
/// failed (logged, retried on the next build).
final swapTokenIconProvider = FutureProvider.autoDispose.family<SwapTokenIcon?, SwapToken>((ref, token) async {
  try {
    return await ref.watch(swapTokenIconServiceProvider).iconFor(token);
  } catch (e) {
    quantusPrint('Logo for ${token.symbol} failed: $e');
    return null;
  }
});

/// The image at a URL, such as a chain's logo; null while it loads or when
/// the fetch failed (logged, retried on the next build).
final swapImageProvider = FutureProvider.autoDispose.family<SwapTokenIcon?, String>((ref, url) async {
  try {
    return await ref.watch(swapTokenIconServiceProvider).imageAt(url);
  } catch (e) {
    quantusPrint('Image $url failed: $e');
    return null;
  }
});

/// Slippage tolerance the next quote asks for, in basis points.
final swapSlippageBpsProvider = StateProvider<int>((_) => SwapService.defaultSlippageBps);
