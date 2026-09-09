import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utility class for reading environment variables
class EnvUtils {
  static String get iosFirebaseApiKey {
    final key = dotenv.env['IOS_FIREBASE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('IOS_FIREBASE_API_KEY is not set in .env file');
    }
    return key;
  }

  static String get androidFirebaseApiKey {
    final key = dotenv.env['ANDROID_FIREBASE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('ANDROID_FIREBASE_API_KEY is not set in .env file');
    }
    return key;
  }

  static String? getEnv(String key) {
    return dotenv.env[key];
  }

  static String getEnvWithFallback(String key, String fallback) {
    return dotenv.env[key] ?? fallback;
  }
}
