import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/providers/service_providers.dart';

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Holds the sign request for the current send session so the QR screen can
/// render instantly after the review screen prefetched it.
class ColdSignCacheNotifier extends StateNotifier<ColdSignRequest?> {
  ColdSignCacheNotifier() : super(null);

  void startNewSession() {
    state = null;
  }

  ColdSignRequest? lookup(ColdSignRequestKey key, {DateTime? now}) {
    final request = state;
    if (request == null || request.key != key) return null;
    if (request.isStale(now)) {
      state = null;
      return null;
    }
    return request;
  }

  void store(ColdSignRequest request) {
    state = request;
  }

  void reset() {
    state = null;
  }
}

final coldSignCacheProvider = StateNotifierProvider<ColdSignCacheNotifier, ColdSignRequest?>(
  (ref) => ColdSignCacheNotifier(),
);

/// Serves a fresh cached request under [key] or builds and caches a new one.
/// [read] is `ref.read` of either a `Ref` or a `WidgetRef`.
Future<ColdSignRequest> ensureColdSignRequest(
  ProviderReader read, {
  required Account account,
  required RuntimeCall Function() buildCall,
  ColdSignRequestKey? key,
  int maxFragmentLength = ColdSignRequest.defaultFragmentLength,
}) async {
  final cache = read(coldSignCacheProvider.notifier);
  if (key != null) {
    final cached = cache.lookup(key);
    if (cached != null) return cached;
  }
  final request = await ColdSignRequest.build(
    account: account,
    call: buildCall(),
    key: key,
    maxFragmentLength: maxFragmentLength,
    substrate: read(substrateServiceProvider),
  );
  if (key != null) cache.store(request);
  return request;
}
