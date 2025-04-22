import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_initializer.dart';
import 'package:resonance_network_wallet/features/main/screens/send_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';

class ResonanceWalletApp extends StatelessWidget {
  const ResonanceWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resonance Network Wallet',
      initialRoute: '/',
      routes: {
        '/': (context) => const WalletInitializer(),
        '/send': (context) => const SendScreen(),
        '/receive': (context) => const ReceiveScreen(),
      },
      theme: ThemeData(
        primaryColor: const Color(0xFF6B46C1), // Deep purple
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Dark background
        cardColor: const Color(0xFF2D2D2D), // Slightly lighter dark for cards
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6B46C1), // Deep purple
          secondary: const Color(0xFF9F7AEA), // Lighter purple
          surface: const Color(0xFF2D2D2D),
          error: Colors.red.shade400,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B46C1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
            side: const BorderSide(color: Color(0xFF9F7AEA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6B46C1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF6B46C1).useOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
          ),
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
        ),
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFF6B46C1),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2D2D2D),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6B46C1),
          secondary: const Color(0xFF9F7AEA),
          surface: const Color(0xFF2D2D2D),
          error: Colors.red.shade400,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B46C1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
            side: const BorderSide(color: Color(0xFF9F7AEA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6B46C1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF6B46C1).useOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
          ),
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
        ),
      ),
      themeMode: ThemeMode.dark,
    );
  }
}
