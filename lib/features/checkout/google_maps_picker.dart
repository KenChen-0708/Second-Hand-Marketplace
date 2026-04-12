import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const String _googlePlacesApiKey = 'AIzaSyADZFFqWrhF2UyOL6If2cYdbRBunjRnq9c';
const LatLng _defaultKualaLumpur = LatLng(3.1390, 101.6869);

class GoogleMapsPicker extends StatefulWidget {
  const GoogleMapsPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  @override
  State<GoogleMapsPicker> createState() => _GoogleMapsPickerState();
}

class _GoogleMapsPickerState extends State<GoogleMapsPicker> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Completer<GoogleMapController> _mapController = Completer();

  LatLng _center = _defaultKualaLumpur;
  String _selectedAddress = 'Loading address...';
  bool _isLoading = true;
  bool _isMapMoving = false;
  bool _isReverseGeocoding = false;
  Timer? _searchDebounce;
  Timer? _reverseGeocodeDebounce;
  List<_PlaceSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseGeocodeDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      _selectedAddress = widget.initialAddress ?? 'Loading address...';
    } else {
      await _goToCurrentLocation(animate: false);
    }

    if (widget.initialAddress == null || widget.initialAddress!.trim().isEmpty) {
      await _reverseGeocode(_center);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _goToCurrentLocation({bool animate = true}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _selectedAddress = 'Location services are disabled';
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _selectedAddress = 'Location permission denied';
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _selectedAddress = 'Location permission permanently denied';
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final target = LatLng(position.latitude, position.longitude);
      _center = target;
      if (animate) {
        await _animateCamera(target, zoom: 17);
      }
    } catch (_) {
      _selectedAddress = 'Unable to get current location';
    }
  }

  Future<void> _animateCamera(
    LatLng target, {
    double zoom = 17,
  }) async {
    if (!_mapController.isCompleted) {
      return;
    }

    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  Future<void> _reverseGeocode(LatLng position) async {
    if (!mounted) {
      return;
    }

    setState(() => _isReverseGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        throw Exception('No address found');
      }

      final place = placemarks.first;
      final address = [
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

      if (mounted) {
        setState(() {
          _selectedAddress = address.isEmpty
              ? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
              : address;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedAddress =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
      }
    }
  }

  Future<void> _searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() => _suggestions = const []);
      }
      return;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': trimmed,
        'key': _googlePlacesApiKey,
        'components': 'country:my',
      },
    );

    try {
      final response = await http.get(uri);
      final body = json.decode(response.body) as Map<String, dynamic>;
      final predictions = (body['predictions'] as List? ?? const [])
          .map(
            (item) => _PlaceSuggestion.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      if (mounted) {
        setState(() => _suggestions = predictions);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _suggestions = const []);
      }
    }
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': suggestion.placeId,
        'fields': 'geometry,name,formatted_address',
        'key': _googlePlacesApiKey,
      },
    );

    try {
      final response = await http.get(uri);
      final body = json.decode(response.body) as Map<String, dynamic>;
      final result = Map<String, dynamic>.from(
        (body['result'] as Map?) ?? <String, dynamic>{},
      );
      final geometry = Map<String, dynamic>.from(
        (result['geometry'] as Map?) ?? <String, dynamic>{},
      );
      final location = Map<String, dynamic>.from(
        (geometry['location'] as Map?) ?? <String, dynamic>{},
      );

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return;
      }

      final target = LatLng(lat, lng);
      _searchFocusNode.unfocus();
      _searchController.text = suggestion.mainText;

      if (mounted) {
        setState(() {
          _center = target;
          _selectedAddress =
              (result['formatted_address']?.toString().trim().isNotEmpty ?? false)
              ? result['formatted_address'].toString()
              : suggestion.description;
          _suggestions = const [];
        });
      }

      await _animateCamera(target);
      await _reverseGeocode(target);
    } catch (_) {
      // Keep current location if place lookup fails.
    }
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
    if (!_isMapMoving && mounted) {
      setState(() => _isMapMoving = true);
    }
  }

  void _onCameraIdle() {
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) {
        return;
      }
      setState(() => _isMapMoving = false);
      await _reverseGeocode(_center);
    });
  }

  Future<void> _confirmSelection() async {
    Navigator.pop(context, {
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                elevation: 4,
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  textInputAction: TextInputAction.search,
                                  onChanged: (value) {
                                    _searchDebounce?.cancel();
                                    _searchDebounce = Timer(
                                      const Duration(milliseconds: 350),
                                      () => _searchPlaces(value),
                                    );
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                  onSubmitted: _searchPlaces,
                                  decoration: InputDecoration(
                                    hintText: 'Search places',
                                    border: InputBorder.none,
                                    prefixIcon: const Icon(Icons.search_rounded),
                                    suffixIcon: _searchController.text.trim().isEmpty
                                        ? null
                                        : IconButton(
                                            icon: const Icon(Icons.close_rounded),
                                            onPressed: () {
                                              _searchController.clear();
                                              _searchFocusNode.unfocus();
                                              setState(() => _suggestions = const []);
                                            },
                                          ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_suggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8, left: 52),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(maxHeight: 260),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final suggestion = _suggestions[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on_outlined),
                                  title: Text(
                                    suggestion.mainText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    suggestion.secondaryText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectSuggestion(suggestion),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 180),
                        offset: _isMapMoving ? const Offset(0, -0.08) : Offset.zero,
                        child: const Icon(
                          Icons.location_pin,
                          size: 52,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 220,
                  child: SafeArea(
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: IconButton(
                        icon: const Icon(Icons.my_location_rounded),
                        onPressed: () async {
                          await _goToCurrentLocation();
                          if (mounted) {
                            setState(() {});
                          }
                          await _reverseGeocode(_center);
                        },
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.place_rounded,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isMapMoving || _isReverseGeocoding
                                          ? 'Adjusting location...'
                                          : 'Selected address',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedAddress,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _confirmSelection,
                              style: FilledButton.styleFrom(
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  factory _PlaceSuggestion.fromMap(Map<String, dynamic> map) {
    final structured = Map<String, dynamic>.from(
      (map['structured_formatting'] as Map?) ?? <String, dynamic>{},
    );

    return _PlaceSuggestion(
      placeId: map['place_id']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      mainText: structured['main_text']?.toString() ?? map['description']?.toString() ?? '',
      secondaryText: structured['secondary_text']?.toString() ?? '',
    );
  }
}
