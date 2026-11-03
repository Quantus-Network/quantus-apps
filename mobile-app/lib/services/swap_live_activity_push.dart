import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/swap_live_activity.dart';

/// Tells Senoti about the card so it can keep sending updates after the app
/// is suspended.
abstract class SwapLiveActivityRegistrar {
  Future<void> register({required String token, required String platform, required SwapLiveActivityContent content});

  Future<void> unregister(String token);
}

/// A non-202 answer is thrown. Callers log it and leave the card up, because
/// the card itself does not depend on the registration.
class SwapLiveActivityPush implements SwapLiveActivityRegistrar {
  final http.Client _client;
  final String endpoint;

  SwapLiveActivityPush({http.Client? client, this.endpoint = AppConstants.senotiEndpoint})
    : _client = client ?? http.Client();

  @override
  Future<void> register({
    required String token,
    required String platform,
    required SwapLiveActivityContent content,
  }) async {
    final response = await _client.post(
      Uri.parse('$endpoint/swap-activities'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(swapLiveActivityRegistrationBody(token: token, platform: platform, content: content)),
    );
    if (response.statusCode != 202) {
      throw Exception('swap activity register failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<void> unregister(String token) async {
    final response = await _client.delete(
      Uri.parse('$endpoint/swap-activities'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'activity_token': token}),
    );
    if (response.statusCode != 202) {
      throw Exception('swap activity unregister failed: ${response.statusCode} ${response.body}');
    }
  }
}
