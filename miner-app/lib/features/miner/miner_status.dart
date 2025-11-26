import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:quantus_miner/src/services/mining_stats_service.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class MinerStatus extends StatelessWidget {
  final MiningStats miningStats;

  const MinerStatus({super.key, required this.miningStats});

  MiningStats get _miningStats => miningStats;

  // Get status configuration based on mining status
  _StatusConfig get _statusConfig {
    switch (_miningStats.status) {
      case MiningStatus.idle:
        return _StatusConfig(
          icon: Icons.pause_circle_outline,
          colors: [const Color(0xFF64748B), const Color(0xFF475569)], // Slate gray
          glowColor: const Color(0xFF64748B),
          label: 'IDLE',
        );
      case MiningStatus.syncing:
        return _StatusConfig(
          icon: Icons.sync,
          colors: [const Color(0xFFFF6B35), const Color(0xFFFF8F65)], // Orange
          glowColor: const Color(0xFFFF6B35),
          label: 'SYNCING',
          isAnimated: true,
        );
      case MiningStatus.mining:
        return _StatusConfig(
          icon: LucideIcons.pickaxe, // Pickaxe-like icon
          colors: [const Color(0xFF10B981), const Color(0xFF059669)], // Green
          glowColor: const Color(0xFF10B981),
          label: 'MINING',
          isPulsing: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_StatusBadge(config: config)],
      ),
    );
  }
}

class _StatusConfig {
  final IconData icon;
  final List<Color> colors;
  final Color glowColor;
  final String label;
  final bool isAnimated;
  final bool isPulsing;

  _StatusConfig({
    required this.icon,
    required this.colors,
    required this.glowColor,
    required this.label,
    this.isAnimated = false,
    this.isPulsing = false,
  });
}

class _StatusBadge extends StatefulWidget {
  final _StatusConfig config;

  const _StatusBadge({required this.config});

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Rotation animation for syncing
    _rotationController = AnimationController(duration: const Duration(seconds: 2), vsync: this);

    // Pickaxe animation for mining (arcing back and forth)
    _pulseController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    // Arc rotation: -30 degrees to +30 degrees (in radians)
    _pulseAnimation = Tween<double>(
      begin: -0.5,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _updateAnimations();
  }

  @override
  void didUpdateWidget(_StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.isAnimated != widget.config.isAnimated ||
        oldWidget.config.isPulsing != widget.config.isPulsing) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    // Handle rotation animation
    if (widget.config.isAnimated) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
      _rotationController.reset();
    }

    // Handle pulse animation
    if (widget.config.isPulsing) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController]),
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.config.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: widget.config.glowColor.useOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon with arcing pickaxe motion
              Transform(
                alignment: Alignment.bottomLeft,
                transform: widget.config.isPulsing
                    ? (Matrix4.identity()..rotateZ(_pulseAnimation.value))
                    : Matrix4.identity(),
                child: RotationTransition(
                  turns: widget.config.isAnimated ? _rotationController : AlwaysStoppedAnimation(0),
                  child: Icon(widget.config.icon, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              // Status label
              Text(
                widget.config.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
