import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class DeepLinkService {
  final Ref _ref;

  DeepLinkService(this._ref);

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> init() async {
    // Handle links when the app is already open (warm state)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      quantusPrint('Received link while app is open: $uri');
      handleLink(uri);
    });

    // Handle the link that opened the app (cold state)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      quantusPrint('Received initial link: $initialUri');
      handleLink(initialUri);
    }
  }

  @visibleForTesting
  void handleLink(Uri uri) {
    // External input is trollable: reject over-long links before any parsing.
    if (uri.toString().length > maxDeepLinkLength) {
      quantusPrint('Ignoring over-long link (${uri.toString().length} chars)');
      return;
    }

    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'account') {
      String? accountId;

      // Check for new format: /account?id=123
      if (uri.pathSegments.length == 1 && uri.queryParameters.containsKey('id')) {
        accountId = uri.queryParameters['id'];
      }
      // Check for old format: /account/123
      else if (uri.pathSegments.length == 2) {
        accountId = uri.pathSegments.last;
      }

      // Fail closed, same as address entry in the send flow.
      if (accountId != null &&
          accountId.length <= maxAddressLength &&
          _ref.read(substrateServiceProvider).isValidSS58Address(accountId)) {
        _ref.read(sharedAccountIntentProvider.notifier).state = accountId;
      } else {
        quantusPrint('Missing or invalid account id');
      }
    }

    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'pay') {
      final payment = PaymentIntent.tryParseUrl(uri.toString());
      // Fail closed: a /pay link with an invalid recipient must not pre-fill
      // the send flow, same as address entry in the send flow itself.
      if (payment != null && _ref.read(substrateServiceProvider).isValidSS58Address(payment.to)) {
        _ref.read(paymentIntentProvider.notifier).state = payment;
      } else {
        quantusPrint('Missing payment parameters or invalid recipient address');
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
