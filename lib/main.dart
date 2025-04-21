import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_initializer.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';

import 'package:resonance_network_wallet/src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await RustLib.init();
  runApp(const ResonanceWalletApp());
}

enum Mode {
  schorr,
  dilithium,
}

const mode = Mode.dilithium;

class ResonanceWalletApp extends StatelessWidget {
  const ResonanceWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resonance Network Wallet',
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
      home: const WalletInitializer(),
    );
  }
}

enum TransactionType {
  sent,
  received,
}

enum TransactionStatus {
  pending,
  confirmed,
  failed,
}

class Transaction {
  final String id;
  final BigInt amount;
  final DateTime timestamp;
  final TransactionType type;
  final String otherParty;
  final TransactionStatus status;

  Transaction({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.otherParty,
    required this.status,
  });
}

// test app for rust bindings below

// import 'package:flutter/material.dart';
// import 'package:resonance_network_wallet/src/rust/api/crypto.dart';
// import 'package:resonance_network_wallet/src/rust/frb_generated.dart';

// Future<void> main() async {
//   await RustLib.init();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final keypair = crystalAlice();
//     final accountId = toAccountId(obj: keypair);

//     debugPrint("alice: ${keypair.publicKey}");
//     debugPrint("bob: ${crystalBob().publicKey}");
//     debugPrint("charlie: ${crystalCharlie().publicKey}");

//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
//         body: Center(
//           child: Text('Action: Call Rust gen key\nResult: $accountId'),
//         ),
//       ),
//     );
//   }
// }
