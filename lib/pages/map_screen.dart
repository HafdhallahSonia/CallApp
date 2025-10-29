import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const MapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _controller;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _markers.add(Marker(
      markerId: const MarkerId("my_position"),
      position: LatLng(widget.latitude, widget.longitude),
      infoWindow: const InfoWindow(title: "My Current Location"),
      onTap: _showSaveDialog,
    ));
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
    final url = Uri.parse("http://10.149.166.230/callapp/save_position.php"); // your server IP
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "pseudo": pseudo,
          "numero": numero,
          "latitude": widget.latitude,
          "longitude": widget.longitude,
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Position saved successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${data['message']}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Location"),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: position,
          zoom: 15,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}
