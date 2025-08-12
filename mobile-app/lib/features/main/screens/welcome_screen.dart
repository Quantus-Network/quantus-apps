import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_and_backup_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/import_wallet_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:video_player/video_player.dart';

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
      extendBodyBehindAppBar: true,
      backgroundColor: context.themeColors.background,
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
                      color: context.themeColors.background,
                    ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height * 0.15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/quantus_logo.svg', // Changed from res_logo_main.svg
                        height: context.themeSize.logoHeight,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Quantum safe\n from the ground up',
                    textAlign: TextAlign.center,
                    style: context.themeText.mediumTitle,
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
                      foregroundColor: context.themeColors.textSecondary,
                      backgroundColor: context.themeColors.light,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'create_wallet'),
                          builder: (context) =>
                              const CreateWalletAndBackupScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Create New Wallet',
                      style: context.themeText.smallTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.themeColors.light,
                      side: BorderSide(color: context.themeColors.light),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'import_wallet'),
                          builder: (context) => const ImportWalletScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Import Existing Wallet',
                      style: context.themeText.smallTitle,
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
