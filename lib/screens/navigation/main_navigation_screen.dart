import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/custom_bottom_navbar.dart';
import '../ai/ai_assistant_screen.dart';
import '../home/home_screen.dart';
import '../liked/liked_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe ke ThemeProvider agar seluruh halaman di IndexedStack ikut ter-rebuild
    // secara instan ketika mode Terang / Gelap diubah.
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    AppColors.isDarkMode = isDark;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final List<Widget> screens = [
      HomeScreen(
        key: ValueKey('home_$isDark'),
        onTabChange: _onTabTapped,
      ),
      OrdersScreen(key: ValueKey('orders_$isDark')),
      AIAssistantScreen(key: ValueKey('ai_$isDark')),
      LikedScreen(key: ValueKey('liked_$isDark')),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Current Tab Page
          IndexedStack(
            index: _currentIndex,
            children: screens,
          ),

          // Sembunyikan Bottom Navbar saat keyboard muncul (user sedang mengetik),
          // dan tampilkan kembali saat selesai mengetik / tekan enter.
          if (!isKeyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomBottomNavbar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
              ),
            ),
        ],
      ),
    );
  }
}
