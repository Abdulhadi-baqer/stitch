import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/alert_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(47.6062, -122.3321);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // State for alerts
  bool groceriesActive = true;
  bool cafeActive = true;
  bool libraryActive = false;
  bool gymActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ProxiAlert',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Current: Downtown Seattle',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                    const Spacer(),
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      child: const Icon(Icons.person, color: Color(0xFF374151)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Map View Container
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: _center,
                            zoom: 11.0,
                          ),
                          myLocationEnabled: false,
                          zoomControlsEnabled: false,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: const Text(
                          'LIVE VIEW',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Active Alerts Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACTIVE ALERTS',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '3 Nearby',
                        style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Alert Cards
                AlertCard(
                  icon: Icons.shopping_cart,
                  iconBackgroundColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  title: 'Groceries near Home',
                  distance: '200m away',
                  isActive: groceriesActive,
                  onChanged: (val) => setState(() => groceriesActive = val),
                ),
                AlertCard(
                  icon: Icons.local_cafe,
                  iconBackgroundColor: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFEA580C),
                  title: '20% off at Local Cafe',
                  distance: '450m away',
                  isActive: cafeActive,
                  onChanged: (val) => setState(() => cafeActive = val),
                ),
                AlertCard(
                  icon: Icons.menu_book,
                  iconBackgroundColor: const Color(0xFFFAF5FF),
                  iconColor: const Color(0xFF9333EA),
                  title: 'Study hours near Library',
                  distance: '1.2km away',
                  isActive: libraryActive,
                  onChanged: (val) => setState(() => libraryActive = val),
                ),
                AlertCard(
                  icon: Icons.fitness_center,
                  iconBackgroundColor: const Color(0xFFF3F4F6),
                  iconColor: Colors.grey.shade500,
                  title: 'Gym Session',
                  distance: '3.5km away',
                  isActive: gymActive,
                  onChanged: (val) => setState(() => gymActive = val),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'DASHBOARD'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'MAP VIEW'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'SETTINGS'),
        ],
      ),
    );
  }
}
