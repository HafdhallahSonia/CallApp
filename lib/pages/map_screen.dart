import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool isFromSavedList;

  const MapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.isFromSavedList = false,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedPosition;
  String _selectedAddress = 'Tap on the map to select a location';
  bool _isLoading = false;
  StreamSubscription<Position>? _positionStream;
  LatLng _currentPosition = const LatLng(0, 0);
  bool _isCurrentPositionSaved = false;

  bool _isSameAsCurrentPosition(double lat, double lng) {
    // Compare with a small epsilon to account for floating point precision
    const double epsilon = 0.000001;
    return (lat - widget.latitude).abs() < epsilon && 
           (lng - widget.longitude).abs() < epsilon;
  }

  Future<void> _showSavedPosition() async {
    if (!mounted) return;
    
    setState(() {
      // Clear existing markers
      _markers.clear();
      
      // Add the saved position marker (green)
      _markers.add(Marker(
        markerId: const MarkerId("saved_position"),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: "Saved Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: _showSaveDialog,
      ));
    });
    
    // Wait for the controller to be initialized
    if (_controller != null) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 15),
      );
    }
  }

  // Fetch all saved positions from the server
  Future<void> _fetchAllSavedPositions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse("http://10.34.180.230/callapp/get_positions.php");
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success'] == 1) {
        final positions = List<Map<String, dynamic>>.from(data['data']);
        
        if (!mounted) return;
        
        setState(() {
          _isCurrentPositionSaved = positions.any((position) {
            final lat = double.parse(position['latitude']);
            final lng = double.parse(position['longitude']);
            return _isSameAsCurrentPosition(lat, lng);
          });

          // Clear existing markers
          _markers.clear();
          
          // Add current position marker
          _markers.add(Marker(
            markerId: const MarkerId("current_position"),
            position: _currentPosition,
            infoWindow: InfoWindow(
              title: _isCurrentPositionSaved ? "Current/Saved Location" : "My Current Location"
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            onTap: () {
              _selectedPosition = _currentPosition;
              _showSaveDialog();
            },
          ));
          
          // Add markers for all saved positions (except those that match current location)
          for (var i = 0; i < positions.length; i++) {
            final position = positions[i];
            final lat = double.parse(position['latitude']);
            final lng = double.parse(position['longitude']);
            
            // Skip if this is the current position (we already have a marker for it)
            if (_isSameAsCurrentPosition(lat, lng)) {
              continue;
            }
            
            _markers.add(Marker(
              markerId: MarkerId('saved_position_$i'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: "Saved Location",
                snippet: '${position['pseudo']} - ${position['numero']}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              onTap: () {
                _selectedPosition = LatLng(lat, lng);
                _showSaveDialog();
              },
            ));
          }
        });
      }
    } catch (e) {
      print('Error fetching saved positions: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Set initial position from widget
    _currentPosition = LatLng(widget.latitude, widget.longitude);
    _selectedPosition = _currentPosition;
    
    // Start location tracking if not opened from saved list
    if (!widget.isFromSavedList) {
      _startLocationTracking();
    }
    
    // Fetch all saved positions - this will handle the markers
    _fetchAllSavedPositions();
  }
  
  @override
  void dispose() {
    // Cancel the position stream when the widget is disposed
    _positionStream?.cancel();
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }
  
  void _startLocationTracking() async {
    // Request location permissions
    var status = await Permission.location.request();
    if (status.isGranted) {
      // Start listening to position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        _updateCurrentPosition(LatLng(position.latitude, position.longitude));
      });
    }
  }
  
  Future<void> _updateCurrentPosition(LatLng newPosition) async {
    if (!mounted) return;
    
    setState(() {
      _currentPosition = newPosition;
      _selectedPosition = newPosition;
      
      // Update or add the current position marker
      _markers.removeWhere((m) => m.markerId.value == 'current_position');
      _markers.add(Marker(
        markerId: const MarkerId("current_position"),
        position: newPosition,
        infoWindow: InfoWindow(
          title: _isCurrentPositionSaved ? "Current/Saved Location" : "My Current Location"
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        onTap: () {
          _selectedPosition = newPosition;
          _showSaveDialog();
        },
      ));
    });
    
    // Move camera to follow the user
    if (_controller != null) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    }
  }
    
  Future<void> _showSaveDialog() async {
    String pseudo = '';
    String numero = '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Position"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Pseudo"),
              onChanged: (val) => pseudo = val,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Numero"),
              keyboardType: TextInputType.phone,
              onChanged: (val) => numero = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (pseudo.isEmpty || numero.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill all fields")),
                );
              } else {
                _savePosition(pseudo, numero);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _savePosition(String pseudo, String numero) async {
    if (_selectedPosition == null) return;
    
    final url = Uri.parse("http://10.34.180.230/callapp/save_position.php");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "pseudo": pseudo,
          "numero": numero,
          "latitude": _selectedPosition!.latitude,
          "longitude": _selectedPosition!.longitude,
        }),
      );

      final data = json.decode(response.body);
      if (mounted) {
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Position saved successfully")),
          );
          // Update the marker to show it's saved
          _markers.removeWhere((m) => m.markerId.value == 'selected_position');
          _markers.add(Marker(
            markerId: const MarkerId('saved_position'),
            position: _selectedPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Saved: $pseudo ($numero)'),
            onTap: _showSaveDialog,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${data['message']}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request failed: $e")),
        );
      }
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    if (!mounted) return;
    
    setState(() {
      _selectedPosition = position;
      _markers.removeWhere((m) => m.markerId.value == 'selected_position');
      _markers.add(Marker(
        markerId: const MarkerId('selected_position'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: _showSaveDialog,
      ));
      _isLoading = true;
    });
    
    // Move camera to selected position
    if (_controller != null) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLng(position),
      );
    }
    
    // Get address for the tapped position
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _selectedAddress = '${place.street}, ${place.locality}, ${place.country}';
          } else {
            _selectedAddress = 'No address found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedAddress = 'Error getting address';
        });
      }
    }

    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _selectedAddress = '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Could not get address';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await geo.locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        if (_controller != null) {
          await _controller?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(location.latitude, location.longitude),
              15,
            ),
          );
        }
        _onMapTapped(LatLng(location.latitude, location.longitude));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find the location')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_controller != null) {
                _controller?.animateCamera(
                  CameraUpdate.newLatLng(_currentPosition),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _controller = controller;
              // If opened from saved list, show the saved position after controller is ready
              if (widget.isFromSavedList) {
                _showSavedPosition();
              }
            },
            onTap: _onMapTapped,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search location...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(15),
                      ),
                      onSubmitted: (_) => _searchLocation(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchLocation,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Text(_selectedAddress),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedPosition != null ? _showSaveDialog : null,
        child: const Icon(Icons.save),
      ),
    );
  }
}
