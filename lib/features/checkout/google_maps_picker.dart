import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class GoogleMapsPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const GoogleMapsPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  });

  @override
  State<GoogleMapsPicker> createState() => _GoogleMapsPickerState();
}

class _GoogleMapsPickerState extends State<GoogleMapsPicker> {
  late GoogleMapController _mapController;
  final Completer<GoogleMapController> _controller = Completer();

  LatLng _selectedLocation = const LatLng(
    3.1390,
    101.6869,
  ); // Default: Kuala Lumpur
  String _selectedAddress = 'Selecting location...';
  bool _isLoading = true;

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
      if (widget.initialAddress != null) {
        _selectedAddress = widget.initialAddress!;
      } else {
        await _reverseGeocode(_selectedLocation);
      }
    } else {
      await _getCurrentLocation();
    }

    _updateMarker();
    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _selectedAddress = 'Location services disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _selectedAddress = 'Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(
        () => _selectedAddress = 'Location permission permanently denied',
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _selectedLocation = LatLng(position.latitude, position.longitude);
      await _reverseGeocode(_selectedLocation);
    } catch (e) {
      setState(() => _selectedAddress = 'Unable to get location: $e');
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _selectedAddress = [
            place.street,
            place.subLocality,
            place.locality,
            place.country,
          ].where((part) => part != null && part.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress =
            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      });
    }
  }

  void _updateMarker() {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('selected_location'),
        position: _selectedLocation,
        draggable: true,
        onDragEnd: (LatLng newPosition) {
          setState(() {
            _selectedLocation = newPosition;
            _reverseGeocode(newPosition);
          });
          _updateMarker();
        },
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    _mapController = controller;
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _reverseGeocode(location);
    });
    _updateMarker();
  }

  Future<void> _confirmSelection() async {
    Navigator.pop(context, {
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Meet-up Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Go to my location',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation,
                      zoom: 15,
                    ),
                    markers: _markers,
                    onTap: _onMapTap,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Location',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedAddress,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _confirmSelection,
                          child: const Text('Confirm Location'),
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
