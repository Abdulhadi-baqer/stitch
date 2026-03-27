import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/alert_card.dart';
import '../services/notification_service.dart';
import '../services/places_service.dart';
import '../models/cafe.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(29.378822, 47.999859);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // State for alerts
  List<Cafe> nearbyCafes = [];
  bool isLoadingCafes = true;
  StreamSubscription<Position>? _positionStreamSubscription;
  Set<String> notifiedCafeIds = {};
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndCafes();
  }

  Future<void> _initializeLocationAndCafes() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        currentPosition = position;
      });

      final placesService = PlacesService();
      final cafes = await placesService.getNearbyCafes(
        position.latitude,
        position.longitude,
      );

      for (var cafe in cafes) {
        cafe.distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          cafe.lat,
          cafe.lon,
        );
      }

      cafes.sort((a, b) => a.distance.compareTo(b.distance));

      setState(() {
        nearbyCafes = cafes;
        isLoadingCafes = false;
      });

      _startLocationStream();
    } catch (e) {
      debugPrint("Error getting location: \$e");
      setState(() {
        isLoadingCafes = false;
      });
    }
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          setState(() {
            currentPosition = position;
          });

          bool needsUiUpdate = false;

          for (var cafe in nearbyCafes) {
            final distance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              cafe.lat,
              cafe.lon,
            );

            if ((cafe.distance - distance).abs() > 2) {
              cafe.distance = distance;
              needsUiUpdate = true;
            }

            if (distance <= 5.0 && !notifiedCafeIds.contains(cafe.id)) {
              notifiedCafeIds.add(cafe.id);
              NotificationService().showNotification(
                id: cafe.id.hashCode,
                title: '\${cafe.name} is incredibly close!',
                body:
                    'You are within 5 meters of \${cafe.name}. Time for a coffee?',
              );
            }
          }

          if (needsUiUpdate) {
            setState(() {
              nearbyCafes.sort((a, b) => a.distance.compareTo(b.distance));
            });
          }
        });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Place Reminder',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Current: Downtown Seattle',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 400,
                        width: double.infinity,
                        child: GoogleMap(
                          myLocationEnabled: true,
                          mapType: MapType.normal,
                          // mapId: 'AIzaSyBim3hUgjVXFWD5OngjgB0kOpYBvCfgoVc',
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: _center,
                            zoom: 14.4746,
                          ),
                          // myLocationEnabled: false,
                          zoomControlsEnabled: false,
                          gestureRecognizers:
                              <Factory<OneSequenceGestureRecognizer>>{
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                        ),
                      ),
                    ),

                    // Positioned(
                    //   bottom: 12,
                    //   left: 12,
                    //   child: Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 12,
                    //       vertical: 6,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: Colors.white,
                    //       borderRadius: BorderRadius.circular(8),
                    //       boxShadow: [
                    //         BoxShadow(
                    //           color: Colors.black.withAlpha(
                    //             (255 * 0.1).toInt(),
                    //           ),
                    //           blurRadius: 4,
                    //         ),
                    //       ],
                    //     ),
                    //     child: const Text(
                    //       'LIVE VIEW',
                    //       style: TextStyle(
                    //         fontWeight: FontWeight.bold,
                    //         fontSize: 12,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
            // Header
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Map View Container
                  const SizedBox(height: 24),
                  // Active Alerts Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ACTIVE ALERTS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isLoadingCafes
                              ? 'Loading...'
                              : '\${nearbyCafes.length} Nearby',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (isLoadingCafes)
                    const Center(child: CircularProgressIndicator())
                  else if (nearbyCafes.isEmpty)
                    const Center(child: Text('No cafes found nearby'))
                  else
                    ...nearbyCafes.map(
                      (cafe) => AlertCard(
                        icon: Icons.local_cafe,
                        iconBackgroundColor: const Color(0xFFFFF7ED),
                        iconColor: const Color(0xFFEA580C),
                        title: cafe.name,
                        distance: cafe.distance < 1000
                            ? '\${cafe.distance.toStringAsFixed(0)}m away'
                            : '\${(cafe.distance / 1000).toStringAsFixed(1)}km away',
                        isActive: true,
                        onChanged: (val) {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await NotificationService().requestPermissions();
          await NotificationService().showNotification(
            title: 'Hello',
            body: 'I am Abdulhadi from Kuwait',
          );
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.notifications),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'DASHBOARD',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'MAP VIEW'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }
}
