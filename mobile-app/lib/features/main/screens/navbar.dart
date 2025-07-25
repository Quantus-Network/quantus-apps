import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:resonance_network_wallet/features/main/screens/notifications_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/transactions_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';

class NavItem {
  final SvgPicture offIcon;
  final SvgPicture onIcon;
  final String label;

  NavItem(this.offIcon, this.onIcon, this.label);
}

// Custom painter for the custom bottom navigation bar
class BottomNavPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    Path path = Path();

    path.moveTo(0, size.height);

    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.lineTo((size.width * 1 / 2) + 80, 0);
    path.lineTo((size.width * 1 / 2), size.height / 2);
    path.lineTo((size.width * 1 / 2) - 80, 0);
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

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = 0;
  final bool _notificationTestDisabled = true; // Flag for notifications

  final List<NavItem> _navItems = [
    NavItem(
      SvgPicture.asset('assets/navbar/home_icon_off.svg'),
      SvgPicture.asset('assets/navbar/home_icon_on.svg'),
      'Home',
    ),
    NavItem(
      SvgPicture.asset('assets/navbar/history_icon_off.svg'),
      SvgPicture.asset('assets/navbar/history_icon_on.svg'),
      'History',
    ),
    NavItem(
      SvgPicture.asset('assets/navbar/floating_button.svg'),
      SvgPicture.asset('assets/navbar/floating_button.svg'),
      'Send',
    ),
    NavItem(
      SvgPicture.asset('assets/navbar/settings_icon_off.svg'),
      SvgPicture.asset('assets/navbar/settings_icon_on.svg'),
      'Settings',
    ),
    NavItem(
      SvgPicture.asset('assets/navbar/notifications_icon_off.svg'),
      SvgPicture.asset('assets/navbar/notifications_icon_on.svg'),
      'Notifications',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index > 2 ? index - 1 : index;
    });
  }

  Widget _buildNavItem(int index, NavItem item) {
    bool isSelected = index > 2
        ? _selectedIndex == index - 1
        : _selectedIndex == index;

    // Floating action button item
    if (index == 2) {
      return SizedBox(
        height: 75,
        width: 70,
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/send');
          },
          child: item.onIcon,
        ),
      );
    }

    // Notification item with test flag
    if (index == 4 && _notificationTestDisabled) {
      return SizedBox(
        height: 32,
        width: 70,
        child: InkWell(
          onTap: null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/navbar/notifications_icon_off.svg',
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
        height: 32,
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [isSelected ? item.onIcon : item.offIcon],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final walletStateManager = Provider.of<WalletStateManager>(context);

    return IndexedStack(
      index: _selectedIndex,
      children: [
        const WalletMain(),
        TransactionsScreen(manager: walletStateManager),
        const SettingsScreen(),
        NotificationsScreen(manager: walletStateManager),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: Colors.transparent,
      height: 90,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 90),
            painter: BottomNavPainter(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _navItems.asMap().entries.map((entry) {
              int index = entry.key;
              NavItem item = entry.value;

              return _buildNavItem(index, item);
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
