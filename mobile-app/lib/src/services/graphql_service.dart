import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class GraphQLService {
  late final ValueNotifier<GraphQLClient> client;

  GraphQLService() {
    // HTTP link for queries and mutations
    final httpLink = HttpLink('${AppConstants.graphQlEndpoint}/graphql');

    // WebSocket link for subscriptions
    final webSocketLink = WebSocketLink(AppConstants.graphQlWsEndpoint);

    // Use a split link to direct traffic to the appropriate link
    final link = Link.split((request) => request.isSubscription, webSocketLink, httpLink);

    client = ValueNotifier(
      GraphQLClient(
        link: link,
        cache: GraphQLCache(store: HiveStore()),
      ),
    );
  }
}
