import 'package:quantus_sdk/quantus_sdk.dart';

sealed class RaiderSubmissionsState {
  const RaiderSubmissionsState();
}

class RaiderSubmissionsOk extends RaiderSubmissionsState {
  final RaidQuest activeRaid;
  final List<String> submissions;

  const RaiderSubmissionsOk({required this.activeRaid, required this.submissions});
}

class NoActiveRaid extends RaiderSubmissionsState {
  const NoActiveRaid();
}

class NoTwitterLinked extends RaiderSubmissionsState {
  const NoTwitterLinked();
}
