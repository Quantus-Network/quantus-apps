import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/notification_card.dart';
import 'package:resonance_network_wallet/services/notification_service.dart';

class NotificationGroup extends StatefulWidget {
  final List<NotificationData> notifications;
  final VoidCallback onDismissAll;
  final Function(String) onDismissSingle;

  const NotificationGroup({
    super.key,
    required this.notifications,
    required this.onDismissAll,
    required this.onDismissSingle,
  });

  @override
  State<NotificationGroup> createState() => _NotificationGroupState();
}

class _NotificationGroupState extends State<NotificationGroup>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _stackController;
  late AnimationController _swipeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _stackAnimation;
  late Animation<Offset> _swipeAnimation;
  bool _isExpanded = false;
  bool _isDismissing = false;
  double _swipeOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _stackController = AnimationController(
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

    _stackAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stackController, curve: Curves.easeInOut),
    );

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _stackController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _stackController.forward();
      } else {
        _stackController.reverse();
      }
    });
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
    widget.onDismissAll();
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
    if (widget.notifications.isEmpty) return const SizedBox.shrink();

    final topNotification = widget.notifications.last;
    final notificationCount = widget.notifications.length;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      left: 16,
      right: 16,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          _handleSwipeUpdate(details.delta.dx);
        },
        onHorizontalDragEnd: (details) {
          _handleSwipeEnd(details.primaryVelocity ?? 0);
        },
        onTap: _toggleExpanded,
        child: SlideTransition(
          position: _slideAnimation,
          child: AnimatedBuilder(
            animation: _swipeController,
            builder: (context, child) {
              return Transform.translate(
                offset: _isDismissing
                    ? _swipeAnimation.value * MediaQuery.of(context).size.width
                    : Offset(_swipeOffset, 0),

                child: AnimatedBuilder(
                  animation: _stackAnimation,
                  builder: (context, child) {
                    // Calculate opacity based on swipe offset
                    final swipeProgress = (_swipeOffset.abs() / 150.0).clamp(
                      0.0,
                      1.0,
                    );
                    final opacity = 1.0 - (swipeProgress * 0.3);

                    return Opacity(
                      opacity: opacity,
                      child: Column(
                        spacing: 24,
                        children: [
                          Stack(
                            children: [
                              NotificationCard(
                                notification: topNotification,
                                onDismiss: () =>
                                    widget.onDismissSingle(topNotification.id),
                                isTopNotification: true,
                              ),

                              Positioned(
                                top: 8,
                                right: 8,
                                child: AnimatedOpacity(
                                  opacity:
                                      !_isExpanded &&
                                          widget.notifications.length > 1
                                      ? 1.0
                                      : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    child: Text(
                                      '${widget.notifications.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Expanded list
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _isExpanded
                                ? MediaQuery.of(context).size.height - 380
                                : 0,
                            child: SingleChildScrollView(
                              child: Column(
                                spacing: 24,
                                children: widget.notifications.reversed
                                    .skip(1)
                                    .map(
                                      (notification) => NotificationCard(
                                        notification: notification,
                                        onDismiss: () => widget.onDismissSingle(
                                          notification.id,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
