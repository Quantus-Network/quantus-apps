import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility class for reading environment variables
class EnvUtils {
  /// Get the Supabase URL from environment variables
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('SUPABASE_URL is not set in .env file');
    }
    return url;
  }

  /// Get the Supabase key from environment variables
  static String get supabaseKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is not set in .env file');
    }
    return key;
  }

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

  /// Get the Supabase client instance
  static SupabaseClient get supabaseClient => Supabase.instance.client;
}
