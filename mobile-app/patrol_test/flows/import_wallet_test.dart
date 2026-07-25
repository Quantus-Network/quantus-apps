import 'package:patrol/patrol.dart';

import '../support/app_launcher.dart';
import '../support/wallet_flows.dart';

void main() {
  patrolTest('import existing wallet from welcome lands on home', ($) async {
    await AppLauncher.launchFresh($);
    await WalletFlows.importFromWelcome($);
  });
}
