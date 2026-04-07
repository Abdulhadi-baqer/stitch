import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/notification_service.dart';
import '../services/notification_preferences_service.dart';
import '../services/places_service.dart';
import '../models/cafe.dart';
import '../screens/settings_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late GoogleMapController mapController;
  LatLng _center = const LatLng(29.378822, 47.999859);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  List<Cafe> _places = [];
  StreamSubscription<Position>? _positionStream;
  final Set<String> _notifiedIds = {};
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  double _searchRadius = 1000;
  bool _cafesEnabled = true;
  bool _restaurantsEnabled = true;
  bool _isRefreshing = false;

  static const double _notifyRadius = 200.0;

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermissions();
    _loadPrefs();
    _initLocation();
  }

  Future<void> _loadPrefs() async {
    final svc = NotificationPreferencesService();
    setState(() {
      _isRefreshing = true;
    });
    final cafes = await svc.getCafesEnabled();
    final restaurants = await svc.getRestaurantsEnabled();
    if (mounted) {
      setState(() {
        _cafesEnabled = cafes;
        _restaurantsEnabled = restaurants;
        _isRefreshing = false;
        _markers = _buildMarkers(_places);
      });
      // Immediately check proximity with current position so the user gets
      // notified right away without needing to move.
      if (_currentPosition != null) {
        _checkProximityNotifications(_currentPosition!);
      }
    }
  }

  Set<Circle> _buildCircle(LatLng center, double radius) => {
    Circle(
      circleId: const CircleId('search_radius'),
      center: center,
      radius: radius,
      fillColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
      strokeColor: const Color(0xFF2563EB),
      strokeWidth: 2,
    ),
  };

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      setState(() {
        _isRefreshing = true;
      });
      final position = await Geolocator.getCurrentPosition();
      final center = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
        _center = center;
        _circles = _buildCircle(center, _searchRadius);
      });
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: 13.0),
        ),
      );
      await _fetchPlaces(position, _searchRadius);
      _startStream();
      setState(() {
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _fetchPlaces(Position pos, double radius) async {
    final svc = PlacesService();
    final results = await Future.wait([
      svc.getNearbyCafes(pos.latitude, pos.longitude, radius: radius),
      svc.getNearbyRestaurants(pos.latitude, pos.longitude, radius: radius),
    ]);

    final combined = [...results[0], ...results[1]];
    for (var p in combined) {
      p.distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        p.lat,
        p.lon,
      );
    }
    combined.sort((a, b) => a.distance.compareTo(b.distance));

    if (mounted) {
      setState(() {
        _places = combined;
        _markers = _buildMarkers(combined);
      });
      // Check immediately — user may already be inside a place without moving.
      _checkProximityNotifications(pos);
    }
  }

  void _checkProximityNotifications(Position pos) {
    bool needsSort = false;
    for (var place in _places) {
      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        place.lat,
        place.lon,
      );
      if ((place.distance - dist).abs() > 2) {
        place.distance = dist;
        needsSort = true;
      }

      final enabled = place.type == PlaceType.cafe
          ? _cafesEnabled
          : _restaurantsEnabled;
      if (dist <= _notifyRadius &&
          enabled &&
          !_notifiedIds.contains(place.id)) {
        _notifiedIds.add(place.id);
        final isCafe = place.type == PlaceType.cafe;
        NotificationService().showNotification(
          id: place.id.hashCode,
          title: '${place.name} is nearby!',
          body:
              'You\'re within ${dist.toStringAsFixed(0)}m of this ${isCafe ? 'cafe' : 'restaurant'}.',
          channel: isCafe
              ? NotificationChannel.cafe
              : NotificationChannel.restaurant,
        );
      }
    }

    if (needsSort) {
      setState(() {
        _places.sort((a, b) => a.distance.compareTo(b.distance));
        _markers = _buildMarkers(_places);
      });
    }
  }

  void _startStream() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2,
          ),
        ).listen((pos) {
          setState(() {
            _currentPosition = pos;
            _circles = _buildCircle(
              LatLng(pos.latitude, pos.longitude),
              _searchRadius,
            );
          });
          _checkProximityNotifications(pos);
        });
  }

  Set<Marker> _buildMarkers(List<Cafe> places) => places
      .where((p) {
        if (p.type == PlaceType.cafe) return _cafesEnabled;
        return _restaurantsEnabled;
      })
      .map((p) {
        final label = p.distance < 1000
            ? '${p.distance.toStringAsFixed(0)}m away'
            : '${(p.distance / 1000).toStringAsFixed(1)}km away';
        return Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.lat, p.lon),
          icon: p.type == PlaceType.restaurant
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
          infoWindow: InfoWindow(title: p.name, snippet: label),
        );
      })
      .toSet();

  Future<void> _refreshPlaces() async {
    if (_currentPosition == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchPlaces(_currentPosition!, _searchRadius);
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    // Clear first so _checkProximityNotifications inside _loadPrefs
    // sees a clean slate and fires for newly-enabled categories.
    _notifiedIds.clear();
    await _loadPrefs();
  }

  void _showRadiusSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RadiusSheet(
        initialRadius: _searchRadius,
        onApply: (radius) async {
          setState(() {
            _searchRadius = radius;
            if (_currentPosition != null) {
              _circles = _buildCircle(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                radius,
              );
            }
          });
          if (_currentPosition != null) {
            mapController.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  zoom: _radiusToZoom(radius),
                ),
              ),
            );
            await _fetchPlaces(_currentPosition!, radius);
          }
        },
      ),
    );
  }

  double _radiusToZoom(double r) =>
      (math.log(156543.03392 * 2.5 / r) / math.ln2).clamp(5.0, 18.0);

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Place Reminder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Monitoring your surroundings',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GoogleMap(
                        myLocationEnabled: true,
                        mapType: MapType.normal,
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: _center,
                          zoom: 13.0,
                        ),
                        markers: _markers,
                        circles: _circles,
                        zoomControlsEnabled: false,
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: _showRadiusSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.radar,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _searchRadius >= 1000
                                    ? '${(_searchRadius / 1000).toStringAsFixed(1)} km'
                                    : '${_searchRadius.toStringAsFixed(0)} m',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'refresh_fab',
                        onPressed: _isRefreshing ? null : _refreshPlaces,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2563EB),
                        shape: const CircleBorder(),
                        child: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2563EB),
                                ),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LegendDot(
                              color: Colors.orange,
                              label: 'Cafe',
                              enabled: _cafesEnabled,
                            ),
                            const SizedBox(height: 4),
                            _LegendDot(
                              color: Colors.green,
                              label: 'Restaurant',
                              enabled: _restaurantsEnabled,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        currentIndex: 0,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 1) _openSettings();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'DASHBOARD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool enabled;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: enabled ? color : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: enabled ? Colors.black87 : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RadiusSheet extends StatefulWidget {
  final double initialRadius;
  final Future<void> Function(double) onApply;

  const _RadiusSheet({required this.initialRadius, required this.onApply});

  @override
  State<_RadiusSheet> createState() => _RadiusSheetState();
}

class _RadiusSheetState extends State<_RadiusSheet> {
  late double _radius;
  bool _applying = false;

  static const double _min = 500;
  static const double _max = 10000;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius.clamp(_min, _max);
  }

  String get _label => _radius >= 1000
      ? '${(_radius / 1000).toStringAsFixed(1)} km'
      : '${_radius.toStringAsFixed(0)} m';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.radar,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Search Radius',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust the radius to find places within a specific area.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.my_location,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  _label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: const Color(0xFFBFD7FF),
              thumbColor: const Color(0xFF2563EB),
              overlayColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              trackHeight: 4,
            ),
            child: Slider(
              value: _radius,
              min: _min,
              max: _max,
              divisions: 19,
              onChanged: (v) => setState(() => _radius = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '500 m',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                Text(
                  '10 km',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _applying
                  ? null
                  : () async {
                      setState(() => _applying = true);
                      Navigator.of(context).pop();
                      await widget.onApply(_radius);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _applying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Apply Radius',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
