import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'map_screen.dart';

class SavedPositionsScreen extends StatefulWidget {
  const SavedPositionsScreen({Key? key}) : super(key: key);

  @override
  _SavedPositionsScreenState createState() => _SavedPositionsScreenState();
}

class _SavedPositionsScreenState extends State<SavedPositionsScreen> {
  List<Map<String, dynamic>> _positions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPositions();
  }

  // Fetch Positions
  Future<void> _fetchPositions() async {
    final url = Uri.parse("http://10.149.166.230/callapp/get_positions.php"); 
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success'] == 1) {
        setState(() {
          _positions = List<Map<String, dynamic>>.from(data['data']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${data['message']}")),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request failed: $e")),
      );
    }
  }

  // Delete Position
  Future<void> _deletePosition(int idPosition) async {
    final url = Uri.parse("http://10.149.166.230/callapp/delete_position.php"); 
    try {
      final response = await http.post(url, body: {"idPosition": idPosition.toString()});
      final data = json.decode(response.body);

      if (data['success'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Position deleted")),
        );
        _fetchPositions(); // refresh list
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

  // Share via SMS
  Future<void> _sharePosition(String numero, double lat, double lon) async {
    final message = "Here is my location: https://www.google.com/maps/search/?api=1&query=$lat,$lon";
    final smsUri = Uri.parse("sms:$numero?body=${Uri.encodeComponent(message)}");
    if (!await launchUrl(smsUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch SMS app")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Positions"),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _positions.isEmpty
              ? const Center(child: Text("No saved positions"))
              : ListView.builder(
                  itemCount: _positions.length,
                  itemBuilder: (context, index) {
                    final pos = _positions[index];
                    return Dismissible(
                      key: Key(pos['idPosition'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Confirm Delete"),
                            content: const Text("Are you sure you want to delete this position?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Delete")),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        _deletePosition(pos['idPosition']);
                      },
                      child: ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.red),
                        title: Text(pos['pseudo'] ?? 'Unknown'),
                        subtitle: Text(
                            "Num: ${pos['numero']}\nLat: ${pos['latitude']}, Lon: ${pos['longitude']}"),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.sms, color: Colors.green),
                              tooltip: "Share via SMS",
                              onPressed: () {
                                _sharePosition(
                                  pos['numero'],
                                  double.parse(pos['latitude']),
                                  double.parse(pos['longitude']),
                                );
                              },
                            ),
                            const Icon(Icons.arrow_forward_ios),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapScreen(
                                latitude: double.parse(pos['latitude']),
                                longitude: double.parse(pos['longitude']),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
