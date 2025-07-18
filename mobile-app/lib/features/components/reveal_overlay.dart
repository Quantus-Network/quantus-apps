import 'package:flutter/material.dart';

class RevealOverlay extends StatelessWidget {
  final VoidCallback onReveal;

  const RevealOverlay({super.key, required this.onReveal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_off, color: Colors.white, size: 40),
          const SizedBox(height: 17),
          const Text(
            'This Recovery Phrase provides access to this wallet, only reveal if you are in a secure location',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 17),
          ElevatedButton(
            onPressed: onReveal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: 1,
                  color: Colors.white.withOpacity(0.15),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 5,
              ),
            ),
            child: const Text(
              'Reveal',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 