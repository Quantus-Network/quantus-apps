import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/notification_service.dart';

class NotificationCard extends StatefulWidget {
  final NotificationData notification;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onDismiss,
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

  Color get titleColor {
    switch (widget.notification.type) {
      case NotificationType.success:
        return const Color(0xFF8AF9A8); // Green
      case NotificationType.warning:
        return const Color(0xFFFADC34); // Yellow
      case NotificationType.error:
        return const Color(0xFFFF2D54); // Red
      default:
        return const Color(0xFF16CECE); // Info
    }
  }

  SvgPicture get icon {
    switch (widget.notification.type) {
      case NotificationType.success:
        return SvgPicture.asset(
          'assets/notification/tick_icon.svg',
          width: 22,
          height: 22,
        );
      case NotificationType.warning:
        return SvgPicture.asset(
          'assets/notification/alert_icon.svg',
          width: 21,
          height: 20,
        );
      case NotificationType.error:
        return SvgPicture.asset(
          'assets/notification/red_alert_icon.svg',
          width: 21,
          height: 20,
        );
      default:
        return SvgPicture.asset(
          'assets/notification/hourglass_icon.svg',
          width: 21,
          height: 21,
        );
    }
  }

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

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        _handleSwipeUpdate(details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        _handleSwipeEnd(details.primaryVelocity ?? 0);
      },
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
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    decoration: ShapeDecoration(
                      color: const Color(0x99313131),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          decoration: ShapeDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 13,
                            children: [
                              Text(
                                notification.accountName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            spacing: 13,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 13,
                                children: [
                                  icon,
                                  Expanded(
                                    child: Column(
                                      spacing: 2,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: notification.title,
                                                style: TextStyle(
                                                  color: titleColor /* Green */,
                                                  fontSize: 14,
                                                  fontFamily: 'Fira Code',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const TextSpan(
                                                text: '  ',
                                                style: TextStyle(
                                                  color: Color(0xFFD9D9D9),
                                                  fontSize: 10,
                                                  fontFamily: 'Fira Code',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    // ignore: lines_longer_than_80_chars
                                                    DatetimeFormattingService.format(
                                                      notification.timestamp,
                                                    ),
                                                style: const TextStyle(
                                                  color: Color(0xFFD9D9D9),
                                                  fontSize: 10,
                                                  fontFamily: 'Fira Code',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          notification.message,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontFamily: 'Fira Code',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

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
                              if (notification.onViewDetails != null)
                                _buildViewDetailsButton(
                                  notification.onViewDetails!,
                                ),
                            ],
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

  Widget _buildViewDetailsButton(VoidCallback onViewDetails) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onTap: onViewDetails,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: ShapeDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: [
              const Text(
                'View Details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w400,
                ),
              ),
              SvgPicture.asset('assets/notification/outward_arrow_icon.svg'),
            ],
          ),
        ),
      ),
    );
  }
}
