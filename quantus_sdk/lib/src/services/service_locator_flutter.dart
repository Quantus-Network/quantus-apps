import 'package:quantus_sdk/src/services/settings_service.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late SettingsService settingsService;
  late SubstrateService substrateService;

  void initialize() {
    settingsService = ServiceLocator().settingsService;
    substrateService = SubstrateService(settingsService);
  }
}
