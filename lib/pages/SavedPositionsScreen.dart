import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/db.dart';
import 'map_screen.dart';
import 'package:another_telephony/telephony.dart';


class SavedPositionsScreen extends StatefulWidget {
  final int userId;

  const SavedPositionsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _SavedPositionsScreenState createState() => _SavedPositionsScreenState();
}

class _SavedPositionsScreenState extends State<SavedPositionsScreen> {
  final DbHelper dbHelper = DbHelper();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];

  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _filteredPositions = [];
  bool _loading = true;

  final TextEditingController _contactSearchController = TextEditingController();
  final TextEditingController _positionSearchController = TextEditingController();
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _fetchPositions();

    _contactSearchController.addListener(_filterContacts);
    _positionSearchController.addListener(_filterPositions);
  }

  @override
  void dispose() {
    _contactSearchController.dispose();
    _positionSearchController.dispose();
    super.dispose();
  }

  // ------------------ Load contacts from DB ------------------
  Future<void> _loadContacts() async {
    final data = await dbHelper.getContacts(widget.userId);
    setState(() {
      _contacts = data.map((c) => {
        "name": "${c['firstname'] ?? ''} ${c['lastname'] ?? ''}".trim(),
        "phone": c['phone'] ?? '',
      }).toList();
      _filteredContacts = List.from(_contacts);
    });
  }

  void _filterContacts() {
    final query = _contactSearchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((c) {
        final name = c['name'].toLowerCase();
        final phone = c['phone'].toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  // ------------------ Fetch saved positions ------------------
  Future<void> _fetchPositions() async {
    final url = Uri.parse("http://10.149.166.230/callapp/get_positions.php");
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success'] == 1) {
        setState(() {
          _positions = List<Map<String, dynamic>>.from(data['data']);
          _filteredPositions = List.from(_positions);
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

  void _filterPositions() {
    final query = _positionSearchController.text.toLowerCase();
      setState(() {
        _filteredPositions = _positions.where((pos) {
          final pseudo = pos['pseudo']?.toLowerCase() ?? '';
          final numero = pos['numero']?.toLowerCase() ?? '';
          return pseudo.contains(query) || numero.contains(query);
        }).toList();
      });
    }

    Future<void> _deletePosition(int idPosition) async {
      final url = Uri.parse("http://10.149.166.230/callapp/delete_position.php");
      try {
        final response = await http.post(url, body: {"idPosition": idPosition.toString()});
        final data = json.decode(response.body);

        if (data['success'] == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Position deleted")),
          );
          _fetchPositions();
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

    // ------------------ Share position ------------------
  void _showShareDialog(double lat, double lon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _contactSearchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search contact...",
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: _filteredContacts.isEmpty
                  ? const Center(child: Text("No contacts found"))
                  : ListView.builder(
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        return ListTile(
                          title: Text(contact['name']),
                          subtitle: Text(contact['phone']),
                          onTap: () async {
                            final numero = contact['phone'];
                            final message =
                                "Location: https://www.google.com/maps/search/?api=1&query=$lat,$lon";

                            // Send SMS directly using another_telephony
                            await telephony.sendSms(
                              to: numero,
                              message: message,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Location sent via SMS")),
                            );

                            Navigator.pop(context); // close dialog
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }


  // ------------------ Build UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Saved Positions",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search for Positions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _positionSearchController,
                decoration: InputDecoration(
                  hintText: "Search positions...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPositions.isEmpty
                      ? const Center(child: Text("No saved positions"))
                      : ListView.builder(
                          itemCount: _filteredPositions.length,
                          itemBuilder: (context, index) {
                            final pos = _filteredPositions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                      icon: const Icon(Icons.share, color: Colors.green),
                                      tooltip: "Share Position",
                                      onPressed: () {
                                        _showShareDialog(
                                          double.parse(pos['latitude']),
                                          double.parse(pos['longitude']),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: "Delete Position",
                                      onPressed: () async {
                                        final confirmed = await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text("Confirm Delete"),
                                            content: const Text(
                                                "Are you sure you want to delete this position?"),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(false),
                                                  child: const Text("Cancel")),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context).pop(true),
                                                  child: const Text("Delete")),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          _deletePosition(pos['idPosition']);
                                        }
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
            ),
          ],
        ),
      ),
    );
  }
}
