import 'package:patrol/patrol.dart';

import '../support/app_launcher.dart';
import '../support/wallet_flows.dart';

void main() {
  patrolTest('create new wallet from welcome lands on home', ($) async {
    await AppLauncher.launchFresh($);
    await WalletFlows.createFromWelcome($);
  });
}
