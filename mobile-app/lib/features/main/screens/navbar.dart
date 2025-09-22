import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resonance_network_wallet/features/main/screens/notifications_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/transactions_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/wallet_main.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class NavItem {
  final String offIcon;
  final String onIcon;
  final String label;

  NavItem(this.offIcon, this.onIcon, this.label);
}

// Custom painter for the custom bottom navigation bar
class BottomNavPainter extends CustomPainter {
  final bool isTablet;
  final Color background;

  BottomNavPainter({
    super.repaint,
    required this.background,
    required this.isTablet,
  });

  double get offset => isTablet ? 130 : 80;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = background
      ..style = PaintingStyle.fill;

    Path path = Path();

    path.moveTo(0, size.height);

    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.lineTo((size.width * 1 / 2) + offset, 0);
    path.lineTo((size.width * 1 / 2), size.height / 2);
    path.lineTo((size.width * 1 / 2) - offset, 0);
    path.lineTo(0, 0);

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class NavbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const NavbarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey,
            size: isSelected ? 30 : 24,
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: isSelected ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class Navbar extends ConsumerStatefulWidget {
  final String? address;

  const Navbar({super.key, this.address});

  @override
  ConsumerState<Navbar> createState() => _NavbarState();
}

class _NavbarState extends ConsumerState<Navbar> {
  int _selectedIndex = 0;
  final bool _notificationTestDisabled = false; // Flag for notifications
  final TelemetryService _telemetry = TelemetryService();

  final List<NavItem> _navItems = [
    NavItem(
      'assets/navbar/home_icon_off.svg',
      'assets/navbar/home_icon_on.svg',
      'Home',
    ),
    NavItem(
      'assets/navbar/history_icon_off.svg',
      'assets/navbar/history_icon_on.svg',
      'History',
    ),
    NavItem(
      'assets/navbar/floating_button.svg',
      'assets/navbar/floating_button.svg',
      'Send',
    ),
    NavItem(
      'assets/navbar/settings_icon_off.svg',
      'assets/navbar/settings_icon_on.svg',
      'Settings',
    ),
    NavItem(
      'assets/navbar/notifications_icon_off.svg',
      'assets/navbar/notifications_icon_on.svg',
      'Notifications',
    ),
  ];

  void _onItemTapped(int index) {
    final newIndex = index > 2 ? index - 1 : index;

    // Track tab navigation centrally
    final toLabel = _labelForIndex(newIndex);
    _telemetry.trackScreenView('tab:$toLabel');

    setState(() {
      _selectedIndex = newIndex;
    });
  }

  String _labelForIndex(int index) {
    // Since index 2 is the floating send button and not part of the tabs,
    // our _selectedIndex never equals 2. The _navItems labels map as below:
    // 0 -> Home, 1 -> History, 3 -> Settings, 4 -> Notifications
    final effectiveIndex = index >= 2 ? index + 1 : index;
    return _navItems[effectiveIndex].label;
  }

  Widget _buildNavItem(int index, NavItem item) {
    bool isSelected = index > 2
        ? _selectedIndex == index - 1
        : _selectedIndex == index;

    // Floating action button item
    if (index == 2) {
      return SizedBox(
        height: context.themeSize.floatingBtnHeight,
        width: context.themeSize.floatingBtnWidth,
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/send');
          },
          child: SvgPicture.asset(item.onIcon),
        ),
      );
    }

    // Notification item with test flag
    if (index == 4 && _notificationTestDisabled) {
      return SizedBox(
        height: context.themeSize.navbarItemHeight,
        width: context.themeSize.navbarItemWidth,
        child: InkWell(
          onTap: null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/navbar/notifications_icon_off.svg',
                width: context.themeSize.navbarIconWidth,
                colorFilter: const ColorFilter.mode(
                  Colors.blueGrey,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () {
        _onItemTapped(index);
      },
      child: SizedBox(
        height: context.themeSize.navbarItemHeight,
        width: context.themeSize.navbarItemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSelected
                ? SvgPicture.asset(
                    item.onIcon,
                    width: context.themeSize.navbarIconWidth,
                  )
                : SvgPicture.asset(
                    item.offIcon,
                    width: context.themeSize.navbarIconWidth,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        WalletMain(address: widget.address),
        const TransactionsScreen(),
        const SettingsScreen(),
        const NotificationsScreen(),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: Colors.transparent,
      height: context.themeSize.navbarHeight,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(
              MediaQuery.of(context).size.width,
              context.themeSize.navbarHeight,
            ),
            painter: BottomNavPainter(
              background: context.themeColors.navbarBg,
              isTablet: context.isTablet,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _navItems.asMap().entries.map((entry) {
                int index = entry.key;
                NavItem item = entry.value;

                return _buildNavItem(index, item);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }
}
