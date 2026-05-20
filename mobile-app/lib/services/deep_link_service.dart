import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';

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
      print('Received link while app is open: $uri');
      _handleLink(uri);
    });

    // Handle the link that opened the app (cold state)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      print('Received initial link: $initialUri');
      _handleLink(initialUri);
    }
  }

  void _handleLink(Uri uri) {
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
      } else {
        print('Missing or empty account id');
      }
    }

    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'pay') {
      final payment = PaymentIntent.tryParseUrl(uri.toString());
      if (payment != null) {
        _ref.read(paymentIntentProvider.notifier).state = payment;
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
