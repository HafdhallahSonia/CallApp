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
  final String? senderNumber;
  final int? pathId;

  const MapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.isFromSavedList = false,
    this.senderNumber,
    this.pathId,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedPosition;
  String _selectedAddress = 'Tap on the map to select a location';
  bool _isLoading = false;
  StreamSubscription<Position>? _positionStream;
  LatLng _currentPosition = const LatLng(0, 0);
  bool _isCurrentPositionSaved = false;

  // Tracking state
  bool _isTracking = false;
  final List<LatLng> _trackedPositions = [];
  int _polylineIdCounter = 1;

  // Server endpoints (change host if needed)
  final String baseUrl = 'http://10.35.112.138/callapp';

  @override
  void initState() {
    super.initState();

    // Set initial position from widget
    _currentPosition = LatLng(widget.latitude, widget.longitude);
    _selectedPosition = _currentPosition;

    // Start location tracking if not opened from saved list (but NOT path tracking)
    if (!widget.isFromSavedList) {
      _startLocationFollowing(); // this will keep current pos updated
    }

    // Fetch saved positions (markers) if you want them displayed
    _fetchAllSavedPositions();

    //load path if pathId is passed
    if (widget.pathId != null) {
      Future.delayed(Duration(milliseconds: 200), () {
        _loadPath(widget.pathId!);
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ------------------------- Permissions & Location helpers -------------------------
  Future<bool> _checkLocationServices() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services to use this feature.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Geolocator.openLocationSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<bool> _checkLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are required')),
          );
        }
        return false;
      }
    }
    return status.isGranted;
  }

  // Follow current location (used whether tracking or not)
  void _startLocationFollowing() async {
    final serviceEnabled = await _checkLocationServices();
    if (!serviceEnabled) return;
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateCurrentPosition(LatLng(position.latitude, position.longitude));

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 5,
            ),
          ).listen(
            (Position position) {
              _updateCurrentPosition(
                LatLng(position.latitude, position.longitude),
              );
              // If tracking, append to the tracked positions and update polyline
              if (_isTracking) {
                _addTrackedPosition(
                  LatLng(position.latitude, position.longitude),
                );
              }
            },
            onError: (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location error: ${e.toString()}')),
                );
              }
            },
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your current location')),
        );
      }
    }
  }

  //updating the polyline on the map that represents the tracked path
  Future<void> _updateCurrentPosition(LatLng newPosition) async {
    if (!mounted) return;
    setState(() {
      _currentPosition = newPosition;
      _selectedPosition = newPosition;
      // Update current marker
      _markers.removeWhere((m) => m.markerId.value == 'current_position');
      _markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: newPosition,
          infoWindow: const InfoWindow(title: 'My Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _showSaveDialog(),
        ),
      );
    });

    // Move camera to follow user (only if not manually moved)
    if (_controller != null) {
      await _controller?.animateCamera(CameraUpdate.newLatLng(newPosition));
    }
  }

  // ------------------------- Tracking helpers -------------------------
  //begins the tracking
  void _startTracking() {
    if (_isTracking) return;
    setState(() {
      _isTracking = true;
      _trackedPositions.clear();
      // add the current position as first point (if available)
      _trackedPositions.add(_currentPosition);
      _polylines.clear();
    });
    _showSnack('Tracking started');
  }

  // ends the tracking
  void _stopTrackingAndPromptSave() async {
    if (!_isTracking) return;
    setState(() {
      _isTracking = false;
    });
    if (_trackedPositions.length < 2) {
      _showSnack('Path too short — nothing saved');
      return;
    }
    await _showSavePathDialog();
  }

  //Adds the new position
  void _addTrackedPosition(LatLng pos) {
    if (!mounted) return;
    setState(() {
      _trackedPositions.add(pos);
      _redrawTrackingPolyline();
    });
  }

  void _redrawTrackingPolyline() {
    final polylineId = PolylineId('tracking_${_polylineIdCounter}');
    _polylineIdCounter++;
    _polylines.removeWhere((p) => p.polylineId.value.startsWith('tracking_'));
    _polylines.add(
      Polyline(
        polylineId: polylineId,
        points: List<LatLng>.from(_trackedPositions),
        width: 5,
        geodesic: false,
      ),
    );
  }

  // ------------------------- Save / Load paths via PHP -------------------------
  Future<void> _showSavePathDialog() async {
    final TextEditingController nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Tracked Path'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Path name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              Navigator.pop(ctx);
              _saveTrackedPath(name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTrackedPath(String name) async {
    if (_trackedPositions.isEmpty) return;
    final url = Uri.parse('$baseUrl/save_path.php');

    final points = _trackedPositions
        .map(
          (p) => {
            'latitude': p.latitude.toString(),
            'longitude': p.longitude.toString(),
          },
        )
        .toList();

    final body = jsonEncode({'name': name, 'points': points});

    try {
      setState(() => _isLoading = true);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSnack('Saved path: $name');
        // Optionally clear current tracked path after saving:
        // setState(() { _trackedPositions.clear(); _polylines.clear(); });
      } else {
        _showSnack('Save failed: ${data['message'] ?? 'server error'}');
      }
    } catch (e) {
      _showSnack('Request failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fetch list of saved paths
  Future<List<Map<String, dynamic>>> _fetchSavedPaths() async {
    final url = Uri.parse('$baseUrl/get_paths.php');
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final List paths = data['data'];
        return List<Map<String, dynamic>>.from(paths);
      } else {
        _showSnack('Could not load saved paths');
        return [];
      }
    } catch (e) {
      _showSnack('Request failed: $e');
      return [];
    }
  }

  // Load a specific path by id and display on map
  Future<void> _loadPath(int id) async {
    final url = Uri.parse('$baseUrl/get_path.php?id=$id');
    try {
      setState(() => _isLoading = true);
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final points = List<Map<String, dynamic>>.from(data['data']);
        if (points.isEmpty) {
          _showSnack('Path empty');
          return;
        }
        final List<LatLng> loaded = points
            .map(
              (p) => LatLng(
                (p['latitude'] as num).toDouble(),
                (p['longitude'] as num).toDouble(),
              ),
            )
            .toList();

        // create polyline for loaded path
        final polyId = PolylineId(
          'loaded_${DateTime.now().millisecondsSinceEpoch}',
        );
        setState(() {
          _polylines.add(
            Polyline(polylineId: polyId, points: loaded, width: 5),
          );
          // add markers for start/end
          _markers.removeWhere(
            (m) =>
                m.markerId.value == 'path_start' ||
                m.markerId.value == 'path_end',
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('path_start'),
              position: loaded.first,
              infoWindow: const InfoWindow(title: 'Start'),
            ),
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('path_end'),
              position: loaded.last,
              infoWindow: const InfoWindow(title: 'End'),
            ),
          );
        });

        // move camera to start point
        await _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(loaded.first, 15),
        );
      } else {
        _showSnack('Could not load path: ${data['message']}');
      }
    } catch (e) {
      _showSnack('Request failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UI to select and load a saved path
  Future<void> _showSavedPathsDialog() async {
    final paths = await _fetchSavedPaths();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 400,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Saved Paths',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: paths.isEmpty
                  ? const Center(child: Text('No saved paths'))
                  : ListView.builder(
                      itemCount: paths.length,
                      itemBuilder: (context, index) {
                        final p = paths[index];
                        return ListTile(
                          title: Text(p['name'] ?? 'Path ${p['id']}'),
                          subtitle: Text('Created: ${p['created_at'] ?? ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _loadPath(int.parse(p['id'].toString()));
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- Save single position (existing) -------------------------
  Future<void> _showSaveDialog({
    String? existingPseudo,
    String? existingNumero,
  }) async {
    final TextEditingController pseudoController = TextEditingController(
      text: existingPseudo ?? '',
    );
    final TextEditingController numeroController = TextEditingController(
      text: existingNumero ?? '',
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Position"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pseudoController,
              decoration: const InputDecoration(labelText: "Pseudo"),
            ),
            TextField(
              controller: numeroController,
              decoration: const InputDecoration(labelText: "Numero"),
              keyboardType: TextInputType.phone,
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
              final pseudo = pseudoController.text.trim();
              final numero = numeroController.text.trim();
              if (pseudo.isEmpty || numero.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill all fields")),
                );
                return;
              }
              Navigator.pop(ctx);
              _saveSinglePosition(pseudo, numero);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSinglePosition(String pseudo, String numero) async {
    if (_selectedPosition == null) return;
    final url = Uri.parse('$baseUrl/save_position.php'); // assumed existing API
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pseudo': pseudo,
          'numero': numero,
          'latitude': _selectedPosition!.latitude,
          'longitude': _selectedPosition!.longitude,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSnack('Position saved successfully');
      } else {
        _showSnack('Error: ${data['message']}');
      }
    } catch (e) {
      _showSnack('Request failed: $e');
    }
  }

  // ------------------------- Fetch existing saved positions to show as markers -------------------------
  Future<void> _fetchAllSavedPositions() async {
    try {
      final url = Uri.parse(
        '$baseUrl/get_positions.php',
      ); // your existing endpoint
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['success'] == 1) {
        final positions = List<Map<String, dynamic>>.from(data['data']);
        setState(() {
          for (var i = 0; i < positions.length; i++) {
            final lat = double.parse(positions[i]['latitude']);
            final lng = double.parse(positions[i]['longitude']);
            _markers.add(
              Marker(
                markerId: MarkerId('saved_$i'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: 'Saved Location',
                  snippet:
                      '${positions[i]['pseudo']} - ${positions[i]['numero']}',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ), // <-- green marker
              ),
            );
          }
        });
      }
    } catch (e) {
      // ignore or show snack
    }
  }

  // ------------------------- Search and map tap -------------------------
  Future<void> _onMapTapped(LatLng position) async {
    if (!mounted) return;

    setState(() {
      _selectedPosition = position;
      _markers.removeWhere((m) => m.markerId.value == 'selected_position');
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_position'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: _showSaveDialog,
        ),
      );
      _isLoading = true;
    });

    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _selectedAddress =
              '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
        });
      } else {
        setState(() {
          _selectedAddress = 'No address found';
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Could not get address';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _isLoading = true);
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find the location')),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------- UI helpers -------------------------
  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------- Build -------------------------
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
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: _showSavedPathsDialog, // open saved paths list
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
            polylines: _polylines,
            onMapCreated: (controller) {
              _controller = controller;
              if (widget.isFromSavedList) {
                // optionally zoom to the initial position
                _controller?.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentPosition, 15),
                );
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Start/Stop tracking button
          FloatingActionButton.extended(
            heroTag: 'trackBtn',
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            label: Text(_isTracking ? 'Stop & Save' : 'Start Tracking'),
            backgroundColor: _isTracking ? Colors.red : Colors.green,
            onPressed: () {
              if (_isTracking) {
                _stopTrackingAndPromptSave();
              } else {
                _startTracking();
              }
            },
          ),
          const SizedBox(height: 12),
          // Show saved paths
          FloatingActionButton(
            heroTag: 'savedListBtn',
            onPressed: _showSavedPathsDialog,
            child: const Icon(Icons.history),
          ),
        ],
      ),
    );
  }
}
