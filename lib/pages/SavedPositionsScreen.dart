import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:another_telephony/telephony.dart';
import '../services/db.dart';
import 'map_screen.dart';

class SavedPositionsScreen extends StatefulWidget {
  final int userId;

  const SavedPositionsScreen({Key? key, required this.userId})
    : super(key: key);

  @override
  _SavedPositionsScreenState createState() => _SavedPositionsScreenState();
}

class _SavedPositionsScreenState extends State<SavedPositionsScreen>
    with SingleTickerProviderStateMixin {
  final DbHelper dbHelper = DbHelper();
  final Telephony telephony = Telephony.instance;

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];

  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _paths = [];

  List<Map<String, dynamic>> _filteredPositions = [];
  List<Map<String, dynamic>> _filteredPaths = [];

  bool _loadingPositions = true;
  bool _loadingPaths = true;

  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterItems);
    _loadContacts();
    _fetchPositions();
    _fetchPaths();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ------------------ Load contacts ------------------
  Future<void> _loadContacts() async {
    final data = await dbHelper.getContacts(widget.userId);
    setState(() {
      _contacts = data
          .map(
            (c) => {
              "name": "${c['firstname'] ?? ''} ${c['lastname'] ?? ''}".trim(),
              "phone": c['phone'] ?? '',
            },
          )
          .toList();
      _filteredContacts = List.from(_contacts);
    });
  }

  // ------------------ Fetch positions ------------------
  Future<void> _fetchPositions() async {
    try {
      final posUrl = Uri.parse(
        "http://10.35.112.138/callapp/get_positions.php",
      );
      final posResp = await http.get(posUrl);
      print("Positions response: ${posResp.body}");
      final posData = json.decode(posResp.body);

      List<Map<String, dynamic>> positions = [];
      if (posData['success'] == 1) {
        positions = List<Map<String, dynamic>>.from(
          posData['data'],
        ).map((p) => {...p, 'type': 'position'}).toList();
      }

      setState(() {
        _positions = positions;
        _filteredPositions = List.from(_positions);
        _loadingPositions = false;
      });
    } catch (e) {
      setState(() => _loadingPositions = false);
      print("Error fetching positions: $e");
    }
  }

  // ------------------ Fetch paths ------------------
  Future<void> _fetchPaths() async {
    try {
      final pathUrl = Uri.parse("http://10.35.112.138/callapp/get_paths.php");
      final pathResp = await http.get(pathUrl);
      print("Paths response: ${pathResp.body}");
      final pathData = json.decode(pathResp.body);

      List<Map<String, dynamic>> paths = [];
      if (pathData['success'] == true) {
        paths = List<Map<String, dynamic>>.from(
          pathData['data'],
        ).map((p) => {...p, 'type': 'path'}).toList();
      }

      setState(() {
        _paths = paths;
        _filteredPaths = List.from(_paths);
        _loadingPaths = false;
      });
    } catch (e) {
      setState(() => _loadingPaths = false);
      print("Error fetching paths: $e");
    }
  }

  // ------------------ Filter ------------------
  void _filterItems() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredPositions = _positions.where((item) {
        final pseudo = item['pseudo']?.toLowerCase() ?? '';
        final numero = item['numero']?.toLowerCase() ?? '';
        return pseudo.contains(query) || numero.contains(query);
      }).toList();

      _filteredPaths = _paths.where((item) {
        final name = item['name']?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
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
              controller: _searchController,
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

                            await telephony.sendSms(
                              to: numero,
                              message: message,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Location sent via SMS"),
                              ),
                            );

                            Navigator.pop(context);
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

  // ------------------ Open MapScreen ------------------
  void _openItem(Map<String, dynamic> item) {
    if (item['type'] == 'position') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapScreen(
            latitude: double.parse(item['latitude']),
            longitude: double.parse(item['longitude']),
            isFromSavedList: true,
          ),
        ),
      );
    } else if (item['type'] == 'path') {
      final id = int.parse(item['id'].toString());
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapScreen(
            latitude: 0,
            longitude: 0,
            isFromSavedList: true,
            pathId: id,
          ),
        ),
      );
    }
  }

  // ------------------ Build UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: "Positions"),
                Tab(text: "Paths"),
              ],
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _loadingPositions
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredPositions.isEmpty
                      ? const Center(child: Text("No saved positions"))
                      : ListView.builder(
                          itemCount: _filteredPositions.length,
                          itemBuilder: (context, index) {
                            final item = _filteredPositions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                ),
                                title: Text(item['pseudo'] ?? 'Unknown'),
                                subtitle: Text(
                                  "Num: ${item['numero']}\nLat: ${item['latitude']}, Lon: ${item['longitude']}",
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => _openItem(item),
                                onLongPress: () {
                                  _showShareDialog(
                                    double.parse(item['latitude']),
                                    double.parse(item['longitude']),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                  _loadingPaths
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredPaths.isEmpty
                      ? const Center(child: Text("No saved paths"))
                      : ListView.builder(
                          itemCount: _filteredPaths.length,
                          itemBuilder: (context, index) {
                            final item = _filteredPaths[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.timeline,
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  item['name'] ?? 'Path ${item['id']}',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => _openItem(item),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
