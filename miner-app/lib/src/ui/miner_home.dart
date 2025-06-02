import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/binary_manager.dart';
import '../services/miner_process.dart';
import '../services/prometheus_service.dart';
import 'miner_controls.dart'; // Import the new widget

class MinerHome extends StatelessWidget {
  // Changed to StatelessWidget
  const MinerHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quantus Miner')),
        body: const Center(
          // Added const
          child: MinerControls(), // Use the new MinerControls widget
        ),
      );
}
