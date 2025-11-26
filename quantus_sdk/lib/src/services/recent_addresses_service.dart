import 'package:shared_preferences/shared_preferences.dart';

class RecentAddressesService {
  static const String _storageKey = 'recent_addresses';
  static const int _maxSize = 100;

  static final RecentAddressesService _instance = RecentAddressesService._internal();

  factory RecentAddressesService() {
    return _instance;
  }

  RecentAddressesService._internal();

  Future<void> addAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> addresses = await getAddresses();

    // Remove if already exists to avoid duplicates
    addresses.remove(address);

    // Add to the beginning (most recent first)
    addresses.insert(0, address);

    // Cap at max size
    if (addresses.length > _maxSize) {
      addresses = addresses.sublist(0, _maxSize);
    }

    // Save back
    await prefs.setStringList(_storageKey, addresses);
  }

  Future<List<String>> getAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }
}
