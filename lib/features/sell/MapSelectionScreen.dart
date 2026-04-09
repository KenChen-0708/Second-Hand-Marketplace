import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Map Selection Screen (OpenStreetMap Version)
// ─────────────────────────────────────────────────────────────────────────────
class MapSelectionScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapSelectionScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late MapController _mapController;
  late LatLng _currentCenter;
  String _currentAddress = "Loading address...";
  bool _isDragging = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<dynamic> _suggestions = [];
  Timer? _debounce;

  // Live Location State
  LatLng? _myLocation;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = LatLng(widget.initialLat, widget.initialLng);
    _fetchAddress(_currentCenter);
    _initLocationTracking(); // Start tracking live location
  }

  @override
  void dispose() {
    _positionStream?.cancel(); // Clean up the GPS stream
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Track Live GPS for the Blue Dot ──
  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Listen to GPS updates continuously
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _myLocation = LatLng(position.latitude, position.longitude);
            });
          }
        });
  }

  // ── 1. OSM Reverse Geocoding (Pin Drop -> Address) ──
  Future<void> _fetchAddress(LatLng pos) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            _currentAddress = [
              place.street,
              place.subLocality,
              place.locality,
            ].where((e) => e != null && e.isNotEmpty).join(', ');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = "Unknown location";
        });
      }
    }
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng currentLoc = LatLng(position.latitude, position.longitude);
      _mapController.move(currentLoc, 17.0);
      _currentCenter = currentLoc;
      _fetchAddress(currentLoc);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get current location')),
        );
    }
  }

  // ── 2. OSM Forward Geocoding (Keyboard Enter -> Location) ──
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    _searchFocus.unfocus();

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng newLoc = LatLng(loc.latitude, loc.longitude);
        _mapController.move(newLoc, 17.0);
        _currentCenter = newLoc;

        setState(() => _suggestions = []);
        _fetchAddress(newLoc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location not found')));
      }
    }
  }

  // ── 3. OSM Autocomplete Suggestions (Nominatim API) ──
  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5&countrycodes=my',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'com.myuniversity.sellapp', // Keep your unique ID here
        },
      );

      if (response.statusCode == 200 && mounted) {
        final List data = json.decode(response.body);
        setState(() {
          _suggestions = data;
        });
      }
    } catch (e) {
      // Ignored for autocomplete typing
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 17.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _searchFocus.unfocus();
                  if (_suggestions.isNotEmpty) {
                    setState(() => _suggestions = []);
                  }
                }
                if (hasGesture && !_isDragging) {
                  setState(() => _isDragging = true);
                }
                if (position.center != null) {
                  _currentCenter = position.center!;
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  setState(() => _isDragging = false);
                  _fetchAddress(_currentCenter);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.myuniversity.sellapp', // Keep your unique ID here
              ),

              // ── Live GPS Blue Dot Marker ──
              if (_myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 24.0,
                      height: 24.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Top Bar (Back Button + Search + Suggestions)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'backBtn',
                        backgroundColor: Colors.white,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _searchLocation,
                            onChanged: (value) {
                              setState(
                                () {},
                              ); // Immediately update UI to show/hide the Clear button

                              if (_debounce?.isActive ?? false)
                                _debounce!.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  _fetchSuggestions(value);
                                },
                              );
                            },
                            decoration: InputDecoration(
                              hintText: 'Search location...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),

                              // ── Dynamic Clear / Cross Button ──
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchFocus.unfocus();
                                        setState(() {
                                          _suggestions = [];
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // OSM Suggestions Dropdown
                  if (_suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 56),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            final displayName =
                                suggestion['display_name'] ??
                                'Unknown location';

                            return ListTile(
                              leading: const Icon(
                                Icons.location_on,
                                color: Colors.grey,
                              ),
                              title: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                _searchFocus.unfocus();
                                _searchController.text = displayName.split(
                                  ',',
                                )[0]; // Set short name

                                final double lat = double.parse(
                                  suggestion['lat'],
                                );
                                final double lon = double.parse(
                                  suggestion['lon'],
                                );
                                final newCenter = LatLng(lat, lon);

                                setState(() {
                                  _suggestions = [];
                                  _currentAddress = displayName;
                                });

                                _mapController.move(newCenter, 17.0);
                                _currentCenter = newCenter;
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Fixed Center Pin (Bounces when dragging)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 42),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(
                  0,
                  _isDragging ? -15 : 0,
                  0,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 42,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ),

          // Bottom Area (FAB + Confirmation Card)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'currentLocBtn',
                  backgroundColor: Colors.white,
                  onPressed: _goToCurrentLocation,
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.place_rounded,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Meeting Point',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isDragging
                                      ? 'Moving map...'
                                      : _currentAddress,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isDragging
                            ? null
                            : () => Navigator.pop(context, _currentAddress),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
