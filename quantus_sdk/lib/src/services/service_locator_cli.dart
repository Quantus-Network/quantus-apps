import 'package:quantus_sdk/src/services/settings_service.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';
import 'package:quantus_sdk/storage_provider_cli.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late SettingsService settingsService;
  late SubstrateService substrateService;

  void initialize() {
    final secureStorage = CliSecureStorageService();
    final prefsStorage = CliPreferencesService();
    settingsService = SettingsService(secureStorage, prefsStorage);
    substrateService = SubstrateService(settingsService);
  }
}
