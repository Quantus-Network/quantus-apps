import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/notification_service.dart';

class NotificationCard extends StatefulWidget {
  final NotificationData notification;
  final VoidCallback onDismiss;
  final bool isTopNotification;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onDismiss,
    this.isTopNotification = false,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _swipeController;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _swipeAnimation;
  bool _isDismissing = false;
  double _swipeOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _handleSwipeDismiss() async {
    if (_isDismissing) return;

    setState(() {
      _isDismissing = true;
    });

    // Animate the swipe out
    final swipeDirection = _swipeOffset > 0 ? 2.0 : -2.0;
    _swipeAnimation = Tween<Offset>(
      begin: Offset(_swipeOffset / MediaQuery.of(context).size.width, 0),
      end: Offset(swipeDirection, 0),
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeIn));

    await _swipeController.forward();
    widget.onDismiss();
  }

  void _handleSwipeUpdate(double delta) {
    if (_isDismissing) return;

    setState(() {
      _swipeOffset += delta;
      // Limit the swipe offset to prevent over-swiping
      _swipeOffset = _swipeOffset.clamp(-150.0, 150.0);
    });
  }

  void _handleSwipeEnd(double velocity) {
    if (_isDismissing) return;

    const double threshold = 80.0; // Threshold distance for dismissal
    const double velocityThreshold =
        500.0; // Velocity threshold for quick swipes

    // Check if swipe meets dismissal criteria
    bool shouldDismiss =
        _swipeOffset.abs() > threshold || velocity.abs() > velocityThreshold;

    if (shouldDismiss) {
      _handleSwipeDismiss();
    } else {
      // Animate back to original position
      _resetSwipePosition();
    }
  }

  void _resetSwipePosition() {
    _swipeAnimation = Tween<Offset>(
      begin: Offset(_swipeOffset / MediaQuery.of(context).size.width, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _swipeController.forward().then((_) {
      setState(() {
        _swipeOffset = 0.0;
      });
      _swipeController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final isNotTopNotification = !widget.isTopNotification;

    return GestureDetector(
      onHorizontalDragUpdate: isNotTopNotification
          ? (details) {
              _handleSwipeUpdate(details.delta.dx);
            }
          : null,
      onHorizontalDragEnd: isNotTopNotification
          ? (details) {
              _handleSwipeEnd(details.primaryVelocity ?? 0);
            }
          : null,
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedBuilder(
          animation: _slideController,
          builder: (context, child) {
            // Calculate opacity based on swipe offset
            final swipeProgress = (_swipeOffset.abs() / 150.0).clamp(0.0, 1.0);
            final opacity = 1.0 - (swipeProgress * 0.3);

            return Transform.translate(
              offset: _isDismissing
                  ? _swipeAnimation.value * MediaQuery.of(context).size.width
                  : Offset(_swipeOffset, 0),
              child: Opacity(
                opacity: opacity,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: notification.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.useOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(notification.icon, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isNotTopNotification)
                          GestureDetector(
                            onTap: widget.onDismiss,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
