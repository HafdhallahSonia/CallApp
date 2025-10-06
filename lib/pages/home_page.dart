// pages/home_page.dart
import 'package:contact_list/pages/export_data.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_contact_page.dart';
import 'categories_screen.dart';
import '../db/db.dart';
import 'package:swipe_to/swipe_to.dart';
import 'dart:io' show Platform;
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final String username;
  final int userId; // ← Ajouté

  const HomePage({
    Key? key,
    required this.username,
    required this.userId, // ← requis
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbHelper = DbHelper();
  String get username => widget.username;
  int get userId => widget.userId; // ← Accès facile
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategId;

  final Color primaryColor = Color(0xFF263A96);

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadCategories();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  // ------------------ Database Methods ------------------
  void _loadContacts() async {
    final data = await dbHelper.getContacts(userId); // ← userId passé ici
    setState(() {
      _allContacts = data;
      _filteredContacts = data;
    });
  }

  void _loadCategories() async {
    final data = await dbHelper.getCategs(userId); // ← userId passé ici
    setState(() {
      _categories = data;
    });
  }

  void _deleteContact(int contactId) async {
    await dbHelper.deleteContact(contactId, userId); // ← userId passé ici
    _loadContacts();
  }

  // ------------------ Filtering ------------------
  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _allContacts.where((contact) {
        final fname = contact['firstname']?.toString().toLowerCase() ?? '';
        final lname = contact['lastname']?.toString().toLowerCase() ?? '';
        final categ = contact['categ_name']?.toString().toLowerCase() ?? '';
        final phone = contact['phone']?.toString().toLowerCase() ?? '';

        final matchesSearch =
            fname.contains(query) ||
            lname.contains(query) ||
            categ.contains(query) ||
            phone.contains(query);

        final matchesCategory =
            _selectedCategId == null || contact['categ_id'] == _selectedCategId;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  // ------------------ Widgets ------------------
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: Text("All"),
            selected: _selectedCategId == null,
            selectedColor: primaryColor.withOpacity(0.2),
            labelStyle: TextStyle(
              color: _selectedCategId == null ? primaryColor : Colors.black,
            ),
            onSelected: (_) {
              setState(() => _selectedCategId = null);
              _filterItems();
            },
          ),
          ..._categories.map((categ) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(categ['categ_name']),
                selected: _selectedCategId == categ['categ_id'],
                selectedColor: primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _selectedCategId == categ['categ_id']
                      ? primaryColor
                      : Colors.black,
                ),
                onSelected: (_) {
                  setState(() => _selectedCategId = categ['categ_id']);
                  _filterItems();
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: "Search by name, phone, or category",
        prefixIcon: Icon(Icons.search, color: primaryColor),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Future<void> _makePhoneCall(String phoneNumber) async {
  //   // Nettoyer le numéro
  //   String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d\+]'), '');
  //   if (cleanNumber.isEmpty) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Numéro invalide")));
  //     return;
  //   }

  //   final Uri uri = Uri(scheme: 'tel', path: cleanNumber);
  //   if (await canLaunchUrl(uri)) {
  //     await launchUrl(
  //       uri,
  //       mode: LaunchMode.externalApplication, // ← Important !
  //     );
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Impossible d'ouvrir l'application Téléphone"),
  //       ),
  //     );
  //   }
  // }

  Future<void> _makePhoneCall(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d\+]'), '');
    if (cleanNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Numéro invalide")));
      return;
    }

    if (Platform.isAndroid) {
      // ✅ ANDROID : Appel direct si permission accordée
      // var status = await Permission.phone.request(); // demande directement
      bool? res = await FlutterPhoneDirectCaller.callNumber(phoneNumber);

      if (res == false) {
        print('Erreur lors du lancement de l\'appel');
      }
    } else {
      // ✅ iOS : ouvrir l'appli Téléphone (seule option)
      await launchUrl(Uri(scheme: 'tel', path: cleanNumber));
    }
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return SwipeTo(
      // Action à gauche = Édition
      onLeftSwipe: (details) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AddContactPage(contact: contact, userId: userId),
          ),
        ).then((_) {
          _loadContacts();
          _filterItems();
        });
      },
      // Action à droite = Suppression
      onRightSwipe: (details) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Delete Contact"),
            content: Text("Are you sure you want to delete this contact?"),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () => Navigator.pop(ctx),
              ),
              TextButton(
                child: Text("Delete", style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteContact(contact['contact_id']);
                },
              ),
            ],
          ),
        );
      },
      // Optionnel : icônes ou widgets pendant le swipe
      iconOnLeftSwipe: Icons.edit,
      leftSwipeWidget: Icon(Icons.edit, color: Colors.blue),
      iconOnRightSwipe: Icons.delete,
      rightSwipeWidget: Icon(Icons.delete, color: Colors.red),

      // Sensibilité (optionnel)
      swipeSensitivity: 10,

      // Le widget enfant (ta carte)
      child: Card(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.grey.withOpacity(0.3),
        margin: EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          trailing: contact['phone'] != null
              ? IconButton(
                  icon: Icon(Icons.call, color: Colors.green),
                  onPressed: () => _makePhoneCall(contact['phone']),
                )
              : null,
          contentPadding: EdgeInsets.all(10),
          leading: CircleAvatar(
            radius: 28,
            child: Text(
              "${contact['firstname'][0]}${contact['lastname'][0]}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: primaryColor,
          ),
          title: Text(
            "${contact['firstname']} ${contact['lastname']}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primaryColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact['phone'] != null)
                Text(
                  "📞 ${contact['phone']}",
                  style: TextStyle(color: Colors.black87),
                ),
              Text(
                "📂 ${contact['categ_name'] ?? 'No Category'}",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
          // Plus de trailing ici → les actions sont gérées par le swipe
        ),
      ),
    );
  }

  Widget _buildContactList() {
    if (_filteredContacts.isEmpty)
      return Center(child: Text("No contacts found"));

    return ListView.builder(
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) =>
          _buildContactCard(_filteredContacts[index]),
    );
  }

  // ------------------ Build Scaffold ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Bonjour, $username', // ← Affiche le username
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: CircleBorder(),
              padding: EdgeInsets.all(8),
            ),
            child: Icon(Icons.upload, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ExportDbPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildCategoryChips(),
            SizedBox(height: 10),
            _buildSearchBar(),
            SizedBox(height: 12),
            Expanded(child: _buildContactList()),
            SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.category, color: Colors.white),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              label: Text(
                'Manage Categories',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CategoriesScreen(userId: userId), // ← userId passé ici
                  ),
                ).then((_) => _loadCategories());
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddContactPage(userId: userId), // ← userId passé ici
            ),
          ).then((_) {
            _loadContacts();
            _filterItems();
          });
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
