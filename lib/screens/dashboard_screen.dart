import 'package:flutter/material.dart';
import 'package:smart_place_reminder/screens/map_screen.dart';
import 'package:smart_place_reminder/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _mapKey = GlobalKey<MapScreenState>();
  List<Widget>? pages;
  int _selectedIndex = 0;
  late PageController pageController;
  @override
  void initState() {
    super.initState();
    pages = [MapScreen(key: _mapKey), SettingsScreen()];
    pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        key: const Key('home-page-view'),
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: pages ?? [],
      ),

      // floatingActionButton: FloatingActionButton.small(
      //   heroTag: 'radius_fab',
      //   onPressed: _showRadiusSheet,
      //   backgroundColor: Colors.white,
      //   foregroundColor: const Color(0xFF2563EB),
      //   shape: const CircleBorder(),
      //   child: const Icon(Icons.radar),
      // ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          // Reload prefs when returning to the map tab so toggle changes
          // made in SettingsScreen are picked up immediately.
          if (index == 0 && _selectedIndex != 0) {
            _mapKey.currentState?.reloadPreferences();
          }
          pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
          );
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'DASHBOARD',
            activeIcon: Icon(Icons.dashboard),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            activeIcon: Icon(Icons.settings),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }
}
