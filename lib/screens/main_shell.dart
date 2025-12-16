import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'calendar_tab.dart';
import 'about_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChanged;

  const MainShell({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  
  // Key to force refresh of tabs when location changes
  Key _refreshKey = UniqueKey();

  bool get isHebrew => widget.locale == 'he';

  void _onLocationChanged() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: KeyedSubtree(
          key: _refreshKey,
          child: IndexedStack(
            index: _currentIndex,
            children: [
              HomeTab(
                locale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
              ),
              CalendarTab(
                locale: widget.locale,
              ),
              AboutScreen(
                locale: widget.locale,
                showAppBar: false,
              ),
              SettingsScreen(
                locale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
                onLocationChanged: _onLocationChanged,
                showAppBar: false,
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: isHebrew ? 'בית' : 'Home',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: isHebrew ? 'לוח שנה' : 'Calendar',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.info_outline,
                activeIcon: Icons.info,
                label: isHebrew ? 'אודות' : 'About',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: isHebrew ? 'הגדרות' : 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? const Color(0xFFE8B923) : Colors.grey[500],
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

