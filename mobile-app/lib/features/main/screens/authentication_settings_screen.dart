import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';

class AuthenticationSettingsScreen extends StatefulWidget {
  const AuthenticationSettingsScreen({super.key});

  @override
  State<AuthenticationSettingsScreen> createState() =>
      _AuthenticationSettingsScreenState();
}

class _AuthenticationSettingsScreenState
    extends State<AuthenticationSettingsScreen> {
  bool _isDeviceAuthEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WalletAppBar(title: 'Authentication Settings'),
              Padding(
                padding: const EdgeInsets.fromLTRB(25.0, 12.0, 25.0, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: const Color(0xFF313131),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authentication',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Use Device Authentication',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isDeviceAuthEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isDeviceAuthEnabled = value;
                          });
                        },
                        activeTrackColor: const Color(0xFF16CECE),
                        inactiveTrackColor: const Color(0xFFD9D9D9),
                        activeColor: Colors.white,
                        inactiveThumbColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
