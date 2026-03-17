import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});

class DeepLinkService {
  final Ref _ref;

  DeepLinkService(this._ref);

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    // Handle links when the app is already open (warm state)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      print('Received link while app is open: $uri');
      _handleLink(uri, navigatorKey);
    });

    // Handle the link that opened the app (cold state)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      print('Received initial link: $initialUri');
      _handleLink(initialUri, navigatorKey);
    }
  }

  void _handleLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
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

      if (accountId != null && accountId.isNotEmpty) {
        _ref.read(sharedAccountIntentProvider.notifier).state = accountId;
        navigatorKey.currentState?.pushNamed('/account');
      } else {
        print('Missing or empty account id');
      }
    }

    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'pay') {
      final to = uri.queryParameters['to'];
      final amount = uri.queryParameters['amount'];
      final ref = uri.queryParameters['ref'];

      if (to != null && to.isNotEmpty && amount != null && amount.isNotEmpty) {
        _ref.read(paymentIntentProvider.notifier).state = PaymentIntent(to: to, amount: amount, ref: ref);
        navigatorKey.currentState?.pushNamed('/account');
      } else {
        print('Missing payment parameters');
      }
    }

    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'oauth') {
      _ref.invalidate(accountAssociationsProvider);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
