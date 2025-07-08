import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:resonance_network_wallet/src/services/graphql_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter(); // For GraphQL caching
  await QuantusSdk.init();
  await SubstrateService().initialize();

  final graphQLService = GraphQLService();

  runApp(GraphQLProvider(client: graphQLService.client, child: const ResonanceWalletApp()));
}
