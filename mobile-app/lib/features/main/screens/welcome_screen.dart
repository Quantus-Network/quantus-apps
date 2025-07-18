import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:resonance_network_wallet/features/main/screens/import_wallet_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_and_backup_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize the controller
    _controller = VideoPlayerController.asset('assets/intro_bg_video.mp4')
      ..initialize()
          .then((_) {
            // Ensure the first frame is shown after the video is initialized
            // and immediately play and loop
            if (!mounted) return; // Check if widget is still mounted
            _controller.play();
            _controller.setLooping(true);
            // Trigger a rebuild once initialized to show the video
            setState(() {});
          })
          .catchError((error) {
            // Handle initialization error
            debugPrint('Video player initialization error: $error');
          });
  }

  @override
  void dispose() {
    // Ensure disposing of the VideoPlayerController to free up resources.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        children: <Widget>[
          // Video Player Background
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: _controller.value.isInitialized
                  ? SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    )
                  : Container(
                      // Placeholder while video loads
                      color: const Color(0xFF0E0E0E),
                      // Optionally, show the static image as placeholder:
                      // child: Image.asset('assets/light_leak_effect_background.jpg', fit: BoxFit.cover),
                    ),
            ),
          ),

          // --- Keep Existing UI Elements ---
          Positioned(
            left: 0,
            right: 0,
            top:
                MediaQuery.of(context).size.height *
                0.15, // Adjust positioning as needed
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 60), // Spacing from Figma
                Center(
                  child: Column(
                    // Wrap in Column to add text below
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/quantus_logo.svg', // Changed from res_logo_main.svg
                        height: 130.0, // Adjust height for the icon
                        fit: BoxFit.contain,
                      ),
                      // const SizedBox(height: 15), // Space between icon and text
                      // const Text(
                      //   'QUANTUS',
                      //   style: TextStyle(
                      //     color: Color(0xFFE6E6E6),
                      //     fontSize: 48, // Adjust font size as needed
                      //     fontFamily: 'Fira Code',
                      //     fontWeight: FontWeight.w100, // Match button weight
                      //     letterSpacing: 3.0, // Added letter spacing
                      //   ),
                      // ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Quantum safe\n from the ground up',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE6E6E6),
                      fontSize: 21,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 27), // Spacing from Figma
              ],
            ),
          ),
          Positioned(
            bottom:
                MediaQuery.of(context).padding.bottom +
                60, // Position above bottom safe area
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color(0xFF0E0E0E),
                      backgroundColor: const Color(0xFFE6E6E6), // Use const
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ), // Use const
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CreateWalletAndBackupScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Create New Wallet',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16), // Use const
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE6E6E6),
                      side: const BorderSide(
                        color: Color(0xFFE6E6E6),
                      ), // Use const
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ), // Use const
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ImportWalletScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Import Existing Wallet',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
